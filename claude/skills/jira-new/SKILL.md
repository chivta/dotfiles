---
name: jira-new
description: Start work on Jira tickets: read them, find their project in ~/Projects, then run the new-task development cycle on them.
argument-hint: <JIRA-KEY> [JIRA-KEY...]
disable-model-invocation: true
---

# Jira task

Tickets: $ARGUMENTS. Together they are one task: one project, one branch.

## 1. Read the tickets

Fetch each with the Atlassian `getJiraIssue` tool, `cloudId: "https://amomobile.atlassian.net"`, `view: "evidence"` (it includes issue links; the umguide tools hold keys that aren't there). Read the comments with `listJiraIssueComments` when there are any, since requirements often change there.

## 2. Find the project

Projects are the git repos directly under `~/Projects`. Sibling directories such as `cd-AT-10722-atlas` are extra worktrees of `cd`; the project is `cd`.

Summary tags like `[BE][CMS]` name the product area, not the repo: AT-10746 "[BE][CMS][Creative builder]..." lives in `amo_file`, not `cms`. Stronger signals:

- Branches named after this ticket, its linked issues or its parent epic:
  `for r in ~/Projects/*/; do git -C "$r" for-each-ref --format="$r %(refname:short)" refs/heads refs/remotes 2>/dev/null; done | grep -E 'AT-(10746|10651)'`
- What the ticket describes against each candidate's README and CLAUDE.md.

Ask with AskUserQuestion when more than one repo stays plausible, when the tickets point to different repos, or when a branch for one of these tickets already exists (the user may want to reuse it).

## 3. Run the development cycle

Read `~/.claude/skills/new-task/SKILL.md` and follow it from its step 3 to the end, with the tickets as the task and this project. Three things differ for tickets:

- The branch name is the ticket keys plus the slug: `AT-10746-gdrive-upload`, `AT-10801-AT-10802-video-retries`.
- The plan's title starts with the ticket keys, and each requirement quotes its ticket, or the later comment that changed it, after that ticket's key: `1. AT-10746: "<quote>"`.
- The Codex review gets the ticket keys and packs the tickets as its skill describes.
