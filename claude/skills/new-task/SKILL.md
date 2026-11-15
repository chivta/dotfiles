---
name: new-task
description: Start a development task in any project, from Jira keys or a description: branch it from its fresh base, explain the task, plan the scope, then implement, trim and check against that plan.
argument-hint: <JIRA-KEY...> | <task description>
disable-model-invocation: true
---

# New task

Task: $ARGUMENTS. It is one task: one project, one branch.

## 1. Read the task

Jira keys such as `AT-10746`: fetch each with the Atlassian `getJiraIssue` tool, `cloudId: "https://amomobile.atlassian.net"`, `view: "evidence"` (it includes issue links; the umguide tools hold keys that aren't there). Read the comments with `listJiraIssueComments` when there are any, since requirements often change there.

Anything else is the task in the user's words; read the pages it links, comments included.

## 2. Find the project

A task in the user's words works on the git repo the session is in, unless it names another. Jira keys, or a session outside any repo, mean one of the git repos directly under `~/Projects`; sibling directories such as `cd-AT-10722-atlas` are extra worktrees of `cd`, and the project is `cd`. Pick it by:

- Branches named after the ticket, its linked issues or its parent epic:
  `for r in ~/Projects/*/; do git -C "$r" for-each-ref --format="$r %(refname:short)" refs/heads refs/remotes 2>/dev/null; done | grep -E 'AT-(10746|10651)'`
- What the task describes against each candidate's README and CLAUDE.md. Summary tags like `[BE][CMS]` name the product area, not the repo: AT-10746 "[BE][CMS][Creative builder]..." lives in `amo_file`, not `cms`.

Ask with AskUserQuestion when more than one repo stays plausible, when the tickets point to different repos, or when a branch for one of these tickets already exists (the user may want to reuse it).

## 3. Branch from the fresh base

The base is `stage` when origin has it, otherwise origin's default branch; in a repo without origin, it's the branch checked out now. Branch name: the ticket keys, if any, plus a 2–4 word English slug of the task, e.g. `AT-10746-gdrive-upload`, `AT-10801-AT-10802-video-retries`, `retry-failed-uploads`.

**Worktree container**, where the project root is a bare repo (`git -C <root> rev-parse --is-bare-repository` prints `true`; `amo_file` and `cms` are):

1. Update local `<base>`. If a worktree has it checked out (`git -C <root> worktree list`; in `cms` it's `cms/stage`), run `git -C <that worktree> pull --ff-only`; otherwise `git -C <root> fetch origin <base>:<base>`.
2. `git -C <root> worktree add -b <branch> <root>/<dir> <base>`. `<dir>` names what the task is about in 1–3 kebab-case words with no ticket key, like `grok-video` or `upload-gdrive`, and must not exist yet.

**Plain checkout**, any other repo:

1. If `git status --porcelain` prints anything, stop and ask; the uncommitted work is the user's.
2. `git switch <base> && git pull --ff-only && git switch -c <branch>`, without the pull when there's no origin.

## 4. Name the session

The session name becomes the kitty tab title, so it has to be readable in a narrow tab: one lowercase word for the task, like `drive` for `upload-gdrive` or `grok` for `grok-video`. Write it with `printf %s <name> > "$TMPDIR/claude-session-title-$CLAUDE_CODE_SESSION_ID"`. Only a hook can rename a session, and `~/.claude/hooks/session-title.sh` applies the name on the user's next prompt.

## 5. Enter the directory

`cd` into the new worktree or repo with Bash. The shell keeps that directory only when it's inside the session's working directories, so use absolute paths for the rest of the run. The built-in `/cd` is user-only; the closing message hands it to the user to move the whole session.

## 6. Explain

Invoke the `explain` skill on the task, reading the code in the new directory. Answer in chat.

## 7. Plan the scope

Write the plan to `.claude/<branch>.md` in the new directory. It is the scope the user approves before any code exists, so it holds only what the task asks for. It's a local file and stays out of every commit.

````markdown
# <ticket keys, if any> <task summary>

Base: `<the base from step 3>`

## Requirements

1. <ticket key, or "Task">: "<requirement quoted from the ticket, the later comment that changed it, or the user's words>"

## Tests

- R1: `<test file>` `<test name>`: <what it asserts>

## Done

```sh
<test, build and lint commands for this repo>
```

## Files

- `<path from the repo root>` — R1
````

Each test fails before the change and passes after it; where the area has no tests, name the command whose output shows the behaviour. Files lists every file the change touches, tests included. `~/.claude/hooks/scope-gate.py` reads that section and blocks Edit and Write on any other file in the worktree, so keep its `` - `path` `` line format; `~/.claude/hooks/check-gate.py` reads the Base line.

After the explanation, paste the whole plan into the chat and ask the user to approve or change it. Then give the branch and the directory. When that directory isn't the session's own, tell the user to run the command below themselves to move the session there, and print it last in its own code block so it copies cleanly:

```
/cd <absolute path of the new directory>
```

## 8. Implement

After the user approves the plan, write its tests first and run them to see them fail, then write the code that makes them pass. Building is done when every command under Done passes: show the commands with their output and write no more code for the plan.

When a requirement turns out to need a file outside Files, add the file there with the requirement it serves; the hook always allows edits to the plan itself. A file no requirement needs stays untouched, however much it invites improvement.

## 9. Trim

Once Done passes, give a fresh-context subagent the plan and the change: `git diff $(git merge-base <base> HEAD)` plus untracked files other than the plan, where `<base>` is the plan's Base. It maps every hunk to the requirement it serves, deletes the hunks that serve none, and reports hunks that break a requirement, quoting it. Fix those, adding code only where a quoted requirement asks for it, then rerun Done. Repeat on what changed since the previous round, three rounds at most; whatever the third round still deletes or reports goes into the final report.

## 10. Check

After the trim, run five checks on the branch in this order, fixing what each one finds before starting the next:

1. the `simplify` skill;
2. the `code-review` skill with `high --fix`;
3. the `security-review` skill;
4. the Codex review: follow `~/.claude/skills/codex-review/SKILL.md` with the plan's ticket keys and its Base as the base branch. For a task without keys, the business review's context is the task in the user's words and the pages it links, verbatim. That skill leaves fixes to the user; here you fix its findings yourself;
5. the `run` skill, to see the change working.

Fix every finding that holds. A finding that asks for behaviour no requirement in the plan names goes into the final report instead of the code, and so does each finding you dismiss, with the reason. Then rerun Done. `~/.claude/hooks/check-gate.py` blocks the hand-back until all five have run in this round.

The final report is where the user's attention comes back, so it carries everything they need to decide on: what each check found and what was fixed, the dismissed findings, what the trim left open, and the Codex review's open questions.
