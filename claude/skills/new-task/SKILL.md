---
name: new-task
description: Start work on Jira tickets: find their project in ~/Projects, branch it from fresh stage, explain the tickets.
argument-hint: <JIRA-KEY> [JIRA-KEY...]
disable-model-invocation: true
---

# New task

Tickets: $ARGUMENTS. Together they are one task: one project, one branch.

## 1. Read the tickets

Fetch each with the Atlassian `getJiraIssue` tool, `cloudId: "https://amomobile.atlassian.net"`, `view: "evidence"` (it includes issue links). Read the comments with `listJiraIssueComments` when there are any, since requirements often change there.

## 2. Find the project

Projects are the git repos directly under `~/Projects`. Sibling directories such as `cd-AT-10722-atlas` are extra worktrees of `cd`; the project is `cd`.

Summary tags like `[BE][CMS]` name the product area, not the repo: AT-10746 "[BE][CMS][Creative builder]..." lives in `amo_file`, not `cms`. Stronger signals:

- Branches named after this ticket, its linked issues or its parent epic:
  `for r in ~/Projects/*/; do git -C "$r" for-each-ref --format="$r %(refname:short)" refs/heads refs/remotes 2>/dev/null; done | grep -E 'AT-(10746|10651)'`
- What the ticket describes against each candidate's README and CLAUDE.md.

Ask with AskUserQuestion when more than one repo stays plausible, when the tickets point to different repos, or when a branch for one of these tickets already exists (the user may want to reuse it).

## 3. Branch from fresh stage

Branch name: the ticket keys plus a 2–4 word English slug of the summary, e.g. `AT-10746-gdrive-upload`, `AT-10801-AT-10802-video-retries`. If origin has no `stage` branch, ask which base to use.

**Worktree container**, where the project root is a bare repo (`git -C <root> rev-parse --is-bare-repository` prints `true`; `amo_file` and `cms` are):

1. Update local `stage`. If a worktree has it checked out (`git -C <root> worktree list`; in `cms` it's `cms/stage`), run `git -C <that worktree> pull --ff-only`; otherwise `git -C <root> fetch origin stage:stage`.
2. `git -C <root> worktree add -b <branch> <root>/<dir> stage`. `<dir>` names what the task is about in 1–3 kebab-case words with no ticket key, like `grok-video` or `upload-gdrive`, and must not exist yet.

**Plain checkout**, any other repo:

1. If `git status --porcelain` prints anything, stop and ask; the uncommitted work is the user's.
2. `git switch stage && git pull --ff-only && git switch -c <branch>`

## 4. Enter the directory

`cd` into the new worktree or repo with Bash. The shell keeps that directory only when it's inside the session's working directories, so use absolute paths for the rest of the run. The built-in `/cd` is user-only; the closing message hands it to the user to move the whole session.

## 5. Explain

Invoke the `explain` skill on the tickets, reading the code in the new directory. Answer in chat; write nothing into the repo.

End with the branch, the directory, and `/cd <absolute path>` on its own line.
