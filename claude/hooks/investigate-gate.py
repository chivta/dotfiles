#!/usr/bin/env -S python3 -I
import json
import os
import re
import shlex
import sys

MARKER_DIR = os.path.join(os.environ.get("TMPDIR") or "/tmp", "claude-investigate-gate")
MCP_GATED = re.compile(r"^mcp__(vm-|vl-|claude_ai_Amo_ES__|amo-es__|plugin_sentry_sentry__)")
CLI_WORD = re.compile(r"\b(kubectl|aws|mysql|redis-cli)\b")
SUBSHELL_CLI = re.compile(r"(\$\(|`|\()\s*(?:\S*/)?(kubectl|aws|mysql|redis-cli)\b")
VAR_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
TIMEOUT_ARG = re.compile(r"^\d+[smhd]?$")
MYSQL_WORD = re.compile(r"\s*(?:\S*/)?mysql(?=\s|$)")
MYSQL_READ_ONLY = re.compile(r"^(SELECT|SHOW|DESCRIBE|DESC|EXPLAIN|WITH)\b", re.I)
MYSQL_FORBIDDEN = re.compile(r"INTO\s+(OUTFILE|DUMPFILE)|FOR\s+UPDATE|LOCK\s+IN\s+SHARE\s+MODE", re.I)
MYSQL_INIT_COMMAND = "--init-command='SET SESSION transaction_read_only=1, max_execution_time=30000'"

PUNCTUATION = "();<>|&"
SEPARATORS = {"|", "||", "&&", ";", "&"}
CLIS = ("kubectl", "aws", "mysql", "redis-cli")
PREFIX_WORDS = {"env", "sudo", "time", "nice", "nohup", "!", "{", "if", "then", "else", "elif", "do", "while", "until"}
WRAPPERS = {"sh", "bash", "zsh", "eval", "exec", "xargs", "watch", "ssh", "python", "python3", "node", "perl", "ruby"}
FILTERS = {"jq", "grep", "egrep", "head", "tail", "sort", "uniq", "wc", "cut", "column", "tr"}

KUBECTL_VALUE_FLAGS = {
    "-n", "--namespace", "--context", "--cluster", "--user", "--kubeconfig", "-s", "--server",
    "--token", "--as", "--as-group", "--as-uid", "--request-timeout", "-v",
}
KUBECTL_VERBS = {
    "get": None, "describe": None, "logs": None, "top": None, "events": None, "explain": None,
    "api-resources": None, "api-versions": None, "version": None, "cluster-info": None,
    "auth": {"can-i", "whoami"},
    "config": {"get-contexts", "current-context"},
}
KUBECTL_SECRET_VERBS = {"get", "describe"}

AWS_VALUE_FLAGS = {
    "--region", "--profile", "--output", "--query", "--endpoint-url", "--cli-read-timeout",
    "--cli-connect-timeout", "--color", "--ca-bundle", "--cli-binary-format",
}
AWS_READ_PREFIXES = ("describe-", "list-", "get-")
AWS_EXTRA_OPERATIONS = {("logs", "start-query"), ("logs", "filter-log-events"), ("logs", "tail"), ("s3", "ls")}
AWS_DENIED_OPERATIONS = {
    "get-secret-value", "get-login-password", "get-authorization-token", "get-session-token",
    "get-federation-token", "get-token", "get-password-data",
}

REDIS_VALUE_FLAGS = {
    "-h", "-p", "-s", "-a", "-u", "-n", "-r", "-i", "-d", "--user", "--pass", "--pattern",
    "--quoted-pattern", "--count", "--cacert", "--cert", "--key", "--sni",
}
REDIS_DENIED_FLAGS = {
    "--eval", "--pipe", "-x", "--rdb", "--functions-rdb", "--replica", "--cluster", "--stat",
    "--bigkeys", "--memkeys", "--hotkeys", "--keystats",
}
REDIS_COMMANDS = {
    name: None
    for name in (
        "GET MGET STRLEN GETRANGE EXISTS TYPE TTL PTTL HGET HMGET HGETALL HKEYS HVALS HLEN HEXISTS HSCAN "
        "LRANGE LLEN LINDEX SMEMBERS SCARD SISMEMBER SSCAN ZRANGE ZREVRANGE ZRANGEBYSCORE ZCARD ZSCORE "
        "ZRANK ZSCAN XRANGE XREVRANGE XLEN XINFO SCAN DBSIZE INFO PING JSON.GET JSON.TYPE FT.SEARCH FT.INFO"
    ).split()
}
REDIS_COMMANDS["MEMORY"] = {"USAGE"}
REDIS_COMMANDS["OBJECT"] = {"ENCODING", "FREQ", "IDLETIME", "REFCOUNT"}

MSG_LOAD_SKILL = (
    'Load the investigate skill first (Skill tool, skill: "investigate"), then retry this call. '
    "It holds the read-only rules and the resource catalog for company infrastructure."
)
MSG_DIRECT = (
    "investigate is read-only: run the CLI directly as one command, optionally piped into "
    + "/".join(sorted(FILTERS))
    + " (no redirects, subshells, env prefixes, wrappers or chaining)."
)
MSG_PARSE = "investigate-gate couldn't parse this command; fix the quoting and run the CLI directly as one command."


def deny(reason):
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}


def split_newlines(cmd):
    out, quote, i = [], None, 0
    while i < len(cmd):
        c = cmd[i]
        if c == "\\" and quote != "'":
            out.append(cmd[i : i + 2])
            i += 2
            continue
        if quote:
            if c == quote:
                quote = None
        elif c in "'\"":
            quote = c
        elif c == "\n":
            c = ";"
        out.append(c)
        i += 1
    return "".join(out)


def tokenize(cmd):
    lex = shlex.shlex(split_newlines(cmd), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    return list(lex)


def is_punctuation(token):
    return bool(token) and all(c in PUNCTUATION for c in token)


def split_segments(tokens, separators):
    segments, current = [], []
    for token in tokens:
        if token in separators:
            segments.append(current)
            current = []
        else:
            current.append(token)
    segments.append(current)
    return segments


def command_index(segment):
    i = 0
    while i < len(segment):
        token = segment[i]
        if VAR_ASSIGN.match(token) or os.path.basename(token) in PREFIX_WORDS:
            i += 1
        elif token == "timeout" and i + 1 < len(segment) and TIMEOUT_ARG.match(segment[i + 1]):
            i += 2
        else:
            break
    return i


def is_gated(tokens):
    for segment in split_segments(tokens, SEPARATORS):
        i = command_index(segment)
        if i >= len(segment):
            continue
        name = os.path.basename(segment[i])
        if name in CLIS:
            return True
        if name in WRAPPERS and any(CLI_WORD.search(t) for t in segment):
            return True
    return False


def positionals(args, value_flags):
    out, i = [], 0
    while i < len(args):
        token = args[i]
        if token.startswith("-"):
            if token in value_flags:
                i += 1
        else:
            out.append(token)
        i += 1
    return out


def check_subcommand(cli, allowed, words):
    fold = str.upper if cli == "redis-cli" else str
    verb = words[0] if words else "(none)"
    if fold(verb) not in allowed:
        return f"investigate is read-only: {cli} `{verb}` isn't allowed; allowed: {', '.join(allowed)}"
    subs = allowed[fold(verb)]
    if subs:
        sub = words[1] if len(words) > 1 else "(none)"
        if fold(sub) not in subs:
            return f"investigate is read-only: {cli} {verb} `{sub}` isn't allowed; allowed: {', '.join(sorted(subs))}"
    return None


def check_kubectl(args):
    words = positionals(args, KUBECTL_VALUE_FLAGS)
    reason = check_subcommand("kubectl", KUBECTL_VERBS, words)
    if reason:
        return reason
    if words[0] in KUBECTL_SECRET_VERBS:
        for arg in args:
            if any(part.lower() in ("secret", "secrets") for part in re.split(r"[,/]", arg)):
                return "investigate is read-only: reading Kubernetes secrets is not allowed; request other resources."
    return None


def check_aws(args):
    if any(a.startswith("--with-decryption") for a in args):
        return "investigate is read-only: --with-decryption is not allowed; omit it."
    words = positionals(args, AWS_VALUE_FLAGS)
    if not words:
        if "--version" in args:
            return None
        return "investigate is read-only: aws needs a service and operation like `ec2 describe-instances`."
    service, operation = words[0], words[1] if len(words) > 1 else ""
    if operation in AWS_DENIED_OPERATIONS:
        return f"investigate is read-only: aws {operation} returns credentials or secrets and is not allowed."
    if operation.startswith(AWS_READ_PREFIXES) or (service, operation) in AWS_EXTRA_OPERATIONS:
        return None
    return (
        f"investigate is read-only: aws {service} `{operation}` isn't allowed; allowed: "
        "describe-*, list-*, get-*, logs start-query, logs filter-log-events, logs tail, s3 ls"
    )


def check_mysql(args):
    queries, i = [], 0
    while i < len(args):
        token = args[i]
        name, eq, value = token.partition("=")
        if token.startswith("--init"):
            return "investigate-gate sets the read-only session itself; remove --init-command."
        if token == "-e":
            queries.append(args[i + 1] if i + 1 < len(args) else "")
            i += 1
        elif token.startswith("-e"):
            queries.append(token[2:])
        elif len(name) >= 4 and "--execute".startswith(name):
            if eq:
                queries.append(value)
            else:
                queries.append(args[i + 1] if i + 1 < len(args) else "")
                i += 1
        i += 1
    if len(queries) != 1:
        return "investigate is read-only: pass exactly one query with -e '<query>'; stdin and interactive sessions are not allowed."
    query = queries[0].strip()
    if query.endswith(";"):
        query = query[:-1]
    if not MYSQL_READ_ONLY.match(query):
        return "investigate is read-only: the MySQL query must start with SELECT, SHOW, DESCRIBE, DESC, EXPLAIN or WITH."
    if ";" in query or "\\" in query:
        return "investigate is read-only: send one statement without `;` or backslash (mysql client commands like \\! run a shell)."
    if MYSQL_FORBIDDEN.search(query):
        return "investigate is read-only: INTO OUTFILE, INTO DUMPFILE, FOR UPDATE and LOCK IN SHARE MODE are not allowed."
    return None


def check_redis(args):
    flags, i = set(), 0
    while i < len(args) and args[i].startswith("-"):
        name = args[i].partition("=")[0]
        if name in REDIS_DENIED_FLAGS or name.startswith("--latency"):
            return f"investigate is read-only: redis-cli {name} isn't allowed; use a read command or --scan."
        flags.add(name)
        if name in REDIS_VALUE_FLAGS and "=" not in args[i]:
            i += 1
        i += 1
    words = args[i:]
    if not words:
        if "--scan" in flags:
            return None
        return "investigate is read-only: redis-cli needs a read command (e.g. GET, HGETALL) or --scan; interactive mode is not allowed."
    return check_subcommand("redis-cli", REDIS_COMMANDS, words)


CHECKS = {"kubectl": check_kubectl, "aws": check_aws, "mysql": check_mysql, "redis-cli": check_redis}


def check_pipeline(cmd):
    stripped = cmd.replace(" 2>&1", "").replace(" 2>/dev/null", "")
    if "`" in stripped or "$(" in stripped:
        return MSG_DIRECT, None
    try:
        tokens = tokenize(stripped)
    except ValueError:
        return MSG_PARSE, None
    if any(is_punctuation(t) and t != "|" for t in tokens):
        return MSG_DIRECT, None
    first, *rest = split_segments(tokens, {"|"})
    if not first or command_index(first) != 0 or os.path.basename(first[0]) not in CHECKS:
        return MSG_DIRECT, None
    if any(not seg or seg[0] not in FILTERS for seg in rest):
        return MSG_DIRECT, None
    cli = os.path.basename(first[0])
    return CHECKS[cli](first[1:]), cli


def handle_bash(tool_input, has_marker):
    cmd = tool_input.get("command") or ""
    try:
        gated = is_gated(tokenize(cmd)) or bool(SUBSHELL_CLI.search(cmd))
    except ValueError:
        if not CLI_WORD.search(cmd):
            return None
        return deny(MSG_PARSE if has_marker else MSG_LOAD_SKILL)
    if not gated:
        return None
    if not has_marker:
        return deny(MSG_LOAD_SKILL)
    reason, cli = check_pipeline(cmd)
    if reason:
        return deny(reason)
    if cli != "mysql":
        return None
    match = MYSQL_WORD.match(cmd)
    if not match:
        return deny("investigate-gate can't rewrite this command; write mysql as the plain first word.")
    rewritten = cmd[: match.end()] + " " + MYSQL_INIT_COMMAND + cmd[match.end() :]
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": "read-only MySQL session enforced by investigate-gate",
            "updatedInput": {**tool_input, "command": rewritten},
        }
    }


def handle_pre_tool_use(data, marker):
    tool = data.get("tool_name") or ""
    tool_input = data.get("tool_input") or {}
    if tool == "Skill":
        skill = tool_input.get("skill") or ""
        if skill == "investigate" or skill.endswith(":investigate"):
            os.makedirs(MARKER_DIR, exist_ok=True)
            open(marker, "a").close()
        return None
    has_marker = os.path.exists(marker)
    if MCP_GATED.match(tool):
        return None if has_marker else deny(MSG_LOAD_SKILL)
    if tool == "Bash":
        return handle_bash(tool_input, has_marker)
    return None


def handle(data):
    event = data.get("hook_event_name")
    session = data.get("session_id") or ""
    marker = os.path.join(MARKER_DIR, f"{session}-{data.get('agent_id') or 'main'}")
    if event == "PreToolUse":
        return handle_pre_tool_use(data, marker)
    if event == "UserPromptSubmit":
        if (data.get("prompt") or "").startswith("/investigate"):
            os.makedirs(MARKER_DIR, exist_ok=True)
            open(os.path.join(MARKER_DIR, f"{session}-main"), "a").close()
    elif event == "SessionStart" and data.get("source") == "compact" and os.path.isdir(MARKER_DIR):
        for name in os.listdir(MARKER_DIR):
            if name.startswith(f"{session}-"):
                os.remove(os.path.join(MARKER_DIR, name))
    return None


def looks_gated(data):
    if data.get("hook_event_name") != "PreToolUse":
        return False
    tool = data.get("tool_name") or ""
    if tool == "Bash":
        return bool(CLI_WORD.search((data.get("tool_input") or {}).get("command") or ""))
    return bool(MCP_GATED.match(tool))


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    try:
        out = handle(data)
    except Exception as e:
        out = deny(f"investigate-gate error: {e}") if looks_gated(data) else None
    if out:
        print(json.dumps(out))


main()
