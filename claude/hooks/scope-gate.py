#!/usr/bin/env -S python3 -I
import json
import os
import re
import subprocess
import sys

PLAN_DIR = ".claude"
PLAN_SUFFIX = ".md"
FILES_HEADING = "## Files"
SECTION_PREFIX = "## "
FILE_ENTRY = re.compile(r"^- `([^`]+)`")

MSG_NOT_LISTED = (
    "`{rel}` isn't in the Files list of `{plan}`. If a requirement in the plan needs this file, "
    "add it to Files as `- `{rel}` — <requirement it serves>` and retry; otherwise leave the file alone."
)


def deny(reason):
    return {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}}


def git(directory, *args):
    result = subprocess.run(["git", "-C", directory, *args], capture_output=True, text=True, check=True)
    return result.stdout.strip()


def nearest_existing_dir(path):
    directory = os.path.dirname(path)
    while not os.path.isdir(directory):
        directory = os.path.dirname(directory)
    return directory


def listed_files(plan_path):
    files = []
    in_section = False
    found = False
    with open(plan_path, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line == FILES_HEADING:
                in_section = found = True
            elif line.startswith(SECTION_PREFIX):
                in_section = False
            elif in_section:
                match = FILE_ENTRY.match(line)
                if match:
                    files.append(match.group(1))
    return files if found else None


def handle(data):
    path = os.path.realpath(data["tool_input"]["file_path"])
    top = os.path.realpath(git(nearest_existing_dir(path), "rev-parse", "--show-toplevel"))
    branch = git(top, "branch", "--show-current")
    if not branch:
        return None
    plan_rel = os.path.join(PLAN_DIR, branch + PLAN_SUFFIX)
    plan_path = os.path.join(top, plan_rel)
    if not os.path.isfile(plan_path) or path == os.path.realpath(plan_path):
        return None
    rel = os.path.relpath(path, top)
    if rel == os.pardir or rel.startswith(os.pardir + os.sep):
        return None
    files = listed_files(plan_path)
    if files is None:
        return None
    allowed = {os.path.relpath(os.path.realpath(os.path.join(top, f)), top) for f in files}
    if rel in allowed:
        return None
    return deny(MSG_NOT_LISTED.format(rel=rel, plan=plan_rel))


def main():
    try:
        out = handle(json.load(sys.stdin))
    except Exception:
        return
    if out:
        print(json.dumps(out))


main()
