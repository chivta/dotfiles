#!/usr/bin/env -S python3 -I
import json
import os
import re
import shutil
import subprocess
import sys

PLAN_DIR = ".claude"
PLAN_SUFFIX = ".md"
FILES_HEADING = "## Files"
SECTION_PREFIX = "## "
BASE_LINE = re.compile(r"^Base: `([^`]+)`$")
STATE_FILE = "claude-check-gate.json"
TEMP_INDEX_PREFIX = "claude-check-gate-index-"
MAX_BLOCKS = 3
BELL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bell.sh")

CODEX_MARKER = "codex-companion.mjs"
CODEX_CHECK = "codex"
COMMAND_PREFIX = "<command-"
COMMAND_NAME = re.compile(r"<command-name>/([^<\s]+)</command-name>")
CHECKS = [
    ("simplify", "`/simplify`"),
    ("code-review", "`/code-review`"),
    ("security-review", "`/security-review`"),
    ("run", "`/run`"),
    (CODEX_CHECK, "the Codex review (`~/.claude/skills/codex-review/SKILL.md`)"),
]

MSG_BLOCK = (
    "This branch's plan is in force and the code changed since the last check round, but these checks "
    "haven't run on it yet: {missing}. Run them as step 10 of the new-task skill describes, fix what they "
    "find, rerun the plan's Done commands, then stop."
)


def git(directory, *args, env=None):
    result = subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True, check=True, env=env)
    return result.stdout.strip()


def has_files_section(plan_path):
    with open(plan_path, encoding="utf-8") as f:
        return FILES_HEADING in f.read().splitlines()


def plan_base(plan_path):
    with open(plan_path, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line.startswith(SECTION_PREFIX):
                return None
            match = BASE_LINE.match(line)
            if match:
                return match.group(1)
    return None


def baseline_tree(top, base):
    try:
        return git(top, "rev-parse", git(top, "merge-base", "HEAD", base) + "^{tree}")
    except subprocess.CalledProcessError:
        return None


def fingerprint(top, git_dir, plan_rel):
    temp_index = os.path.join(git_dir, f"{TEMP_INDEX_PREFIX}{os.getpid()}")
    try:
        real_index = os.path.join(git_dir, "index")
        if os.path.exists(real_index):
            shutil.copyfile(real_index, temp_index)
        env = {**os.environ, "GIT_INDEX_FILE": temp_index}
        git(top, "rm", "--cached", "--ignore-unmatch", "-q", "--", plan_rel, env=env)
        git(top, "add", "-A", "--", ".", f":(exclude){plan_rel}", env=env)
        return git(top, "write-tree", env=env)
    finally:
        if os.path.exists(temp_index):
            os.remove(temp_index)


def load_state(path):
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_state(path, **state):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state, f)


def skill_check(name):
    return name.rsplit(":", 1)[-1]


def message_text(content):
    if isinstance(content, str):
        return content
    return "".join(block.get("text", "") for block in content if block.get("type") == "text")


def checks_in_line(line):
    entry = json.loads(line)
    message = entry.get("message") or {}
    content = message.get("content")
    found = set()
    if entry.get("type") == "user" and content:
        text = message_text(content).lstrip()
        match = COMMAND_NAME.search(text)
        if text.startswith(COMMAND_PREFIX) and match:
            found.add(skill_check(match.group(1)))
    elif entry.get("type") == "assistant" and isinstance(content, list):
        for block in content:
            if block.get("type") != "tool_use":
                continue
            tool_input = block.get("input") or {}
            if block.get("name") == "Skill":
                found.add(skill_check(tool_input.get("skill") or ""))
            elif block.get("name") == "Bash" and CODEX_MARKER in (tool_input.get("command") or ""):
                found.add(CODEX_CHECK)
    return found


def recorded_checks(lines):
    found = set()
    for line in lines:
        try:
            found |= checks_in_line(line)
        except ValueError:
            continue
    return found


def handle(data):
    top = git(data["cwd"], "rev-parse", "--show-toplevel")
    branch = git(top, "branch", "--show-current")
    if not branch:
        return None
    plan_rel = os.path.join(PLAN_DIR, branch + PLAN_SUFFIX)
    plan_path = os.path.join(top, plan_rel)
    if not os.path.isfile(plan_path) or not has_files_section(plan_path):
        return None

    git_dir = os.path.join(top, git(top, "rev-parse", "--git-dir"))
    state_path = os.path.join(git_dir, STATE_FILE)
    state = load_state(state_path)
    current = fingerprint(top, git_dir, plan_rel)
    with open(data["transcript_path"], encoding="utf-8") as f:
        lines = f.read().splitlines()

    def allow():
        save_state(state_path, fingerprint=current, session_id=data["session_id"], transcript_line=len(lines), blocks=0)
        return None

    if state is None:
        base = plan_base(plan_path)
        baseline = baseline_tree(top, base) if base else None
        if baseline is None or baseline == current:
            return allow()
        state = {"fingerprint": baseline, "session_id": data["session_id"], "transcript_line": 0, "blocks": 0}
    elif state["fingerprint"] == current:
        return allow()
    start = state["transcript_line"] if state["session_id"] == data["session_id"] else 0
    found = recorded_checks(lines[start:])
    missing = [label for check, label in CHECKS if check not in found]
    if not missing or state["blocks"] >= MAX_BLOCKS:
        return allow()
    save_state(state_path, **{**state, "blocks": state["blocks"] + 1})
    return {"decision": "block", "reason": MSG_BLOCK.format(missing=", ".join(missing))}


def main():
    try:
        out = handle(json.load(sys.stdin))
    except Exception:
        out = None
    if out:
        print(json.dumps(out))
    else:
        subprocess.run([BELL])


main()
