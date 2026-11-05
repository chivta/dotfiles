#!/usr/bin/env python3
import json
import os
import re
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"
HOME_PROJECTS = str(Path.home() / "Projects") + "/"
SATURDAY = 5
PROMPT_LIMIT = 200
PROMPTS_PER_DAY = 20
REPLY_LIMIT = 400
SKIPPED_PREFIXES = (
    "This session is being continued",
    "The user started this session",
    "[Request interrupted",
    "Another Claude session",
)
COMMAND_NAME_RE = re.compile(r"<command-name>(.*?)</command-name>", re.S)
COMMAND_ARGS_RE = re.compile(r"<command-args>(.*?)</command-args>", re.S)
PASTED_RE = re.compile(r"<pasted_content[^>]*>.*?</pasted_content[^>]*>", re.S)
COMMIT_INLINE_RE = re.compile(
    r"\bgit\b[^\n;&|]*?\bcommit\b[^\n;&|]*?\s-[a-zA-Z]*m\s*(?:\"((?:[^\"\\]|\\.)*)\"|'([^']*)')", re.S
)
COMMIT_HEREDOC_RE = re.compile(
    r"\bgit\b[^\n;&|]*?\bcommit\b[^\n;&|]*?\s-[a-zA-Z]*F\s*-?\s*<<-?\s*['\"]?(\w+)['\"]?\n(.*?)\n\1", re.S
)


def previous_working_day(today):
    day = today - timedelta(days=1)
    while day.weekday() >= SATURDAY:
        day -= timedelta(days=1)
    return day


def local_time(timestamp):
    return datetime.fromisoformat(timestamp.replace("Z", "+00:00")).astimezone()


def one_line(text, limit):
    return " ".join(text.split())[:limit]


def prompt_text(content):
    if isinstance(content, list):
        if any(block.get("type") == "tool_result" for block in content):
            return None
        content = "\n".join(block.get("text", "") for block in content if block.get("type") == "text")
    text = content.strip()
    command = COMMAND_NAME_RE.search(text)
    if command:
        args = COMMAND_ARGS_RE.search(text)
        return one_line(f"{command.group(1)} {args.group(1) if args else ''}", PROMPT_LIMIT)
    if not text or text.startswith(SKIPPED_PREFIXES):
        return None
    if text.startswith("<") and not text.startswith("<pasted_content"):
        return None
    return one_line(PASTED_RE.sub("[pasted]", text), PROMPT_LIMIT)


def commit_message(command):
    inline = COMMIT_INLINE_RE.search(command)
    if inline:
        message = inline.group(1) if inline.group(1) is not None else inline.group(2)
    else:
        heredoc = COMMIT_HEREDOC_RE.search(command)
        if not heredoc:
            return None
        message = heredoc.group(2)
    lines = [line.strip() for line in message.splitlines()]
    return next((line for line in lines if line and not line.startswith("$(")), None)


def new_day():
    return {"start": None, "end": None, "prompts": [], "commits": [], "prs": [], "reply": None}


def read_transcript(path, session_id, start, days, meta, is_subagent):
    pending_commits = {}
    with open(path, encoding="utf-8") as transcript:
        for raw in transcript:
            try:
                record = json.loads(raw)
            except json.JSONDecodeError:
                continue
            kind = record.get("type")
            if kind == "custom-title":
                meta[session_id]["custom_title"] = record.get("customTitle")
            elif kind == "ai-title":
                meta[session_id]["ai_title"] = record.get("aiTitle")
            if "timestamp" not in record:
                continue
            moment = local_time(record["timestamp"])
            if moment < start:
                continue
            day = days[(moment.date(), session_id)]
            if not is_subagent:
                day["start"] = min(day["start"] or moment, moment)
                day["end"] = max(day["end"] or moment, moment)
                if record.get("cwd"):
                    meta[session_id]["cwd"] = record["cwd"]
                if record.get("gitBranch"):
                    meta[session_id]["branch"] = record["gitBranch"]
            content = (record.get("message") or {}).get("content")
            if kind == "pr-link" and record.get("prUrl") not in day["prs"]:
                day["prs"].append(record["prUrl"])
            elif kind == "user" and not is_subagent and not record.get("isMeta"):
                prompt = prompt_text(content)
                if prompt and len(day["prompts"]) < PROMPTS_PER_DAY:
                    day["prompts"].append(prompt)
            if kind == "user" and isinstance(content, list):
                for block in content:
                    message = pending_commits.pop(block.get("tool_use_id"), None)
                    if message and not block.get("is_error") and message not in day["commits"]:
                        day["commits"].append(message)
            if kind == "assistant" and isinstance(content, list):
                for block in content:
                    if block.get("type") == "text" and block.get("text", "").strip() and not is_subagent:
                        day["reply"] = one_line(block["text"], REPLY_LIMIT)
                    if block.get("type") == "tool_use" and block.get("name") == "Bash":
                        message = commit_message(block.get("input", {}).get("command", ""))
                        if message:
                            pending_commits[block.get("id")] = message


def main():
    now = datetime.now().astimezone()
    start = datetime.combine(previous_working_day(now.date()), time.min).astimezone()
    current_session = os.environ.get("CLAUDE_CODE_SESSION_ID")
    days = defaultdict(new_day)
    meta = defaultdict(dict)

    for path in PROJECTS_DIR.glob("*/*.jsonl"):
        if path.stem != current_session and path.stat().st_mtime >= start.timestamp():
            read_transcript(path, path.stem, start, days, meta, is_subagent=False)
    for path in PROJECTS_DIR.glob("*/*/subagents/*.jsonl"):
        session_id = path.parent.parent.name
        if session_id != current_session and path.stat().st_mtime >= start.timestamp():
            read_transcript(path, session_id, start, days, meta, is_subagent=True)

    print(f"# Claude Code sessions {start:%Y-%m-%d %H:%M} → {now:%Y-%m-%d %H:%M}")
    current_date = None
    ordered = sorted(
        ((key, day) for key, day in days.items() if day["start"]),
        key=lambda item: item[1]["start"],
    )
    for (day_date, session_id), day in ordered:
        if not (day["prompts"] or day["commits"] or day["prs"]):
            continue
        if day_date != current_date:
            current_date = day_date
            print(f"\n## {day_date:%Y-%m-%d %A}")
        info = meta[session_id]
        project = info.get("cwd", "?").replace(HOME_PROJECTS, "")
        titles = " / ".join(t for t in (info.get("custom_title"), info.get("ai_title")) if t)
        header = " · ".join(p for p in (project, info.get("branch"), titles) if p)
        print(f"\n### {header} · {day['start']:%H:%M}–{day['end']:%H:%M}")
        for label, items in (("prompts", day["prompts"]), ("commits", day["commits"]), ("PRs", day["prs"])):
            if items:
                print(f"{label}:")
                for item in items:
                    print(f"- {item}")
        if day["reply"]:
            print(f"last reply: {day['reply']}")


if __name__ == "__main__":
    main()
