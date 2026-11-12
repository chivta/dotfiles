#!/usr/bin/env -S python3 -I
import json
import os
import re
import shlex
import sys

MARKER_DIR = os.path.join(os.environ.get("TMPDIR") or "/tmp", "claude-investigate-gate")
MCP_GATED = re.compile(r"^mcp__(vm-|vl-|claude_ai_Amo_ES__|amo-es__|plugin_sentry_sentry__)")
CLI_WORD = re.compile(r"\b(kubectl|aws)\b")
SUBSHELL_CLI = re.compile(r"(\$\(|`|\()\s*(?:\S*/)?(kubectl|aws)\b")
VAR_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
TIMEOUT_ARG = re.compile(r"^\d+[smhd]?$")

PUNCTUATION = "();<>|&"
SEPARATORS = {"|", "||", "&&", ";", "&"}
CLIS = ("kubectl", "aws")
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
    verb = words[0] if words else "(none)"
    if verb not in allowed:
        return f"investigate is read-only: {cli} `{verb}` isn't allowed; allowed: {', '.join(allowed)}"
    subs = allowed[verb]
    if subs:
        sub = words[1] if len(words) > 1 else "(none)"
        if sub not in subs:
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


CHECKS = {"kubectl": check_kubectl, "aws": check_aws}


def check_pipeline(cmd):
    stripped = cmd.replace(" 2>&1", "").replace(" 2>/dev/null", "")
    if "`" in stripped or "$(" in stripped:
        return MSG_DIRECT
    try:
        tokens = tokenize(stripped)
    except ValueError:
        return MSG_PARSE
    if any(is_punctuation(t) and t != "|" for t in tokens):
        return MSG_DIRECT
    first, *rest = split_segments(tokens, {"|"})
    if not first or command_index(first) != 0 or os.path.basename(first[0]) not in CHECKS:
        return MSG_DIRECT
    if any(not seg or seg[0] not in FILTERS for seg in rest):
        return MSG_DIRECT
    return CHECKS[os.path.basename(first[0])](first[1:])


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
    reason = check_pipeline(cmd)
    return deny(reason) if reason else None


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
