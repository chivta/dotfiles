---
name: start-review
description: Start reviewing a GitHub pull request: find or clone its repo in ~/Projects, check the PR branch out, explain the ticket and the PR.
argument-hint: <PR url>
disable-model-invocation: true
---

# Start review

PR: $ARGUMENTS.

## 1. Read the PR

`gh pr view <url> --json number,title,body,url,baseRefName,headRefName,headRepositoryOwner,isCrossRepository,author,files,commits,reviews,comments` gives everything in one call. Keep `headRefName` and `baseRefName`; the rest feeds the explanation.

The Jira keys are the `AT-\d+` matches in the title, the head branch and the body, in that order. Fetch each with the Atlassian `getJiraIssue` tool, `cloudId: "https://amomobile.atlassian.net"`, `view: "evidence"` (it includes issue links). Read the comments with `listJiraIssueComments` when there are any, since requirements often change there. If no key is found, the PR body is the whole spec; say so in the explanation.

## 2. Find or clone the repo

Projects are the git repos directly under `~/Projects`. Match on the origin URL, not the directory name: `cd` is `amomama/amo_content_delivery`.

`for r in ~/Projects/*/; do echo "$r $(git -C "$r" remote get-url origin 2>/dev/null)"; done | grep -F '<owner>/<repo>'`

Several matches are the project plus its extra worktrees, such as `cd` and `cd-AT-10722-atlas`; the project is the shortest path. No match: `gh repo clone <owner>/<repo> ~/Projects/<repo>`.

## 3. Check the PR branch out

**Worktree container**, where the project root is a bare repo (`git -C <root> rev-parse --is-bare-repository` prints `true`; `amo_file` and `cms` are):

1. `git -C <root> fetch origin pull/<number>/head:<headRefName>`. This also works for PRs from forks. If the branch already exists locally, fetch with `+pull/<number>/head:<headRefName>` to move it.
2. If `git -C <root> worktree list` shows a worktree on that branch, use it. Otherwise `git -C <root> worktree add <root>/<dir> <headRefName>`, where `<dir>` names what the PR is about in 1–3 kebab-case words with no ticket key, like `grok-video`, and must not exist yet.
3. Fetch the base too, `git -C <root> fetch origin <baseRefName>:<baseRefName>` (pull inside the worktree that has it checked out instead, as `cms/stage`), so the diff below is against fresh base.

**Plain checkout**, any other repo:

1. If `git status --porcelain` prints anything, stop and ask; the uncommitted work is the user's.
2. `gh pr checkout <url>` from inside the repo; it handles forks and existing local branches. Then `git fetch origin <baseRefName>`.

## 4. Name the session

The session name becomes the kitty tab title, so it has to be readable in a narrow tab: one lowercase word for the PR, like `drive` for an upload-to-gdrive PR. Write it with `printf %s <name> > "$TMPDIR/claude-session-title-$CLAUDE_CODE_SESSION_ID"`. Only a hook can rename a session, and `~/.claude/hooks/session-title.sh` applies the name on the user's next prompt.

## 5. Enter the directory

`cd` into the worktree or repo with Bash. The shell keeps that directory only when it's inside the session's working directories, so use absolute paths for the rest of the run. The built-in `/cd` is user-only; the closing message hands it to the user to move the whole session.

## 6. Explain

Invoke the `explain` skill on the tickets and the PR together, reading the code in the checked-out directory. The change to explain is `git diff origin/<baseRefName>...HEAD` (three dots: only the PR's own commits). Cover what the ticket asks for and how the PR's data flow delivers it; open review threads from `reviews` and `comments` are context for what is still contested, not a verdict. This is the briefing before the review, so explain and don't judge; the review is the user's next prompt. Answer in chat; write nothing into the repo.

End with the branch and the directory, then tell the user to run the command below themselves to move the session there, and print it last in its own code block so it copies cleanly:

```
/cd <absolute path of the checked-out directory>
```
