---
name: codex-review
description: Review the branch diff against its parent branch with two parallel Codex gpt-6.1-sol runs, one for code quality and one for business correctness against the Jira tickets.
argument-hint: "[JIRA-KEY...] [base-branch]"
disable-model-invocation: true
---

# Codex review

Arguments: $ARGUMENTS. Jira keys and a base branch, both optional.

Two Codex runs review the same diff in parallel. The code review never sees the tickets, so it judges the code on its own terms. The business review gets the whole ticket context in its prompt, because Codex has no Jira access and knows only what the prompt carries.

## 1. Pin the diff

Run `git fetch origin`, then pick the base branch: the one in the arguments, else the open PR's base (`gh pr view --json baseRefName -q .baseRefName`), else the closest long-lived branch:

```
for b in stage develop main master; do git rev-parse -q --verify origin/$b >/dev/null && echo "$(git rev-list --count origin/$b..HEAD) $b"; done | sort -n | head -1
```

`SHA=$(git merge-base origin/<BASE> HEAD)`. The review covers `git diff $SHA` (commits plus uncommitted changes) and untracked files. If both are empty, stop and say so.

## 2. Pack the ticket context

Keys come from the arguments, else from the branch name (`AT-10801-AT-10802-video-retries` holds two). With no key, ask the user; if there is no ticket, run only the code review and say the business review was skipped.

Fetch with the Atlassian tools, `cloudId: "https://amomobile.atlassian.net"`, `view: "evidence"` (the umguide tools for keys that aren't there), and collect:

- each ticket: summary, type, status, description, acceptance criteria, every text custom field, and all comments (`listJiraIssueComments`);
- its parent epic, subtasks and every linked issue, with the same fields and comments;
- Confluence pages linked from any of them (`getConfluenceContent`);
- links you can't fetch (Figma, Google Docs, Loom) as URLs with the sentence around them.

Stop one hop from the tickets: links of linked issues aren't followed. Paste everything verbatim, comments in chronological order with author and date, because later comments often change the requirements and a summary drops the details this review exists to check.

## 3. Run Codex

Both runs go through the Codex plugin's companion runtime, which tracks them as jobs visible in `/codex:status` and `/codex:result`. In a new directory under the scratchpad, write `code-prompt.md` and `business-prompt.md` from the templates below, filling `<BASE>`, `<SHA>` and the context. Start both runs from the repo root with Bash `run_in_background: true`:

```
companion=$(ls -d ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | sort -V | tail -1)
node "$companion" task --model gpt-6.1-sol --effort high --prompt-file <dir>/code-prompt.md > <dir>/code.md 2> <dir>/code.log
```

and the same with `business` in place of `code`. Without `--write` the task runs in a read-only sandbox. Each run takes several minutes and you are notified when it exits. stdout holds only Codex's final message and stderr its progress; on a non-zero exit or an empty stdout file, report the tail of the log instead of that review. If the companion reports Codex missing or unauthenticated, tell the user to run `/codex:setup`.

`code-prompt.md`:

```xml
<task>
Review `git diff <SHA>` (this branch's changes since it left <BASE>, uncommitted ones included) and the untracked files in `git status --short`. Read the surrounding code as needed.
Judge the code alone, as if you knew nothing about why it was written: readability and style, simplifications, duplication of existing helpers, wasted work and resources, and inconsistency with how the rest of the codebase does the same thing (naming, layout, error handling, libraries, tests). The repo's CLAUDE.md and AGENTS.md files and the "Project conventions" and "Comments" sections of ~/.claude/CLAUDE.md are the house rules.
Whether the change does the right thing for the product is out of scope; a separate review covers it.
</task>

<grounding_rules>
Cite the path:line in the diff for every finding, and the existing code it is inconsistent with when there is one. Label inferences as inferences.
</grounding_rules>

<structured_output_contract>
Findings ordered by impact, each as: `path:line` — the problem — the concrete change. No praise and no summary of the diff. If nothing is worth changing, say so in one line.
</structured_output_contract>
```

`business-prompt.md`:

```xml
<task>
Review `git diff <SHA>` (this branch's changes since it left <BASE>, uncommitted ones included) and the untracked files in `git status --short` against the business context below. Read the surrounding code to trace how data actually flows.
Check whether the change does what the tickets ask: requirements missing or partly implemented, requirements misread, behaviour that contradicts a comment, the epic or a linked ticket, and edge cases the context names or implies that the code mishandles. Where a later comment disagrees with the description, the comment wins.
Then check the opposite direction: every business behaviour the diff adds that no requirement asks for, such as an extra feature, option, status, field, endpoint, fallback, setting, or handling of a case the context never mentions. Mark each one unnecessary, because only what the tickets ask for ships: every extra is code to maintain and behaviour nobody signed off on. Code a requirement can't be built without (plumbing, the refactors it forces, tests) is not a feature and stays off this list.
Last, suggest lines the author can add to their task prompts or CLAUDE.md so the coding agent stops adding such extras. Read ~/.claude/CLAUDE.md and the repo's CLAUDE.md and AGENTS.md first; where a rule there already forbids an extra, quote it and suggest sharper wording that would have caught this case.
Code style is out of scope; a separate review covers it.
</task>

<business_context>
<the packed ticket context, verbatim>
</business_context>

<grounding_rules>
Cite for every finding the requirement (ticket key and a quote) and the path:line that breaks or misses it. Label inferences and open questions as such.
</grounding_rules>

<structured_output_contract>
1. Requirements checklist: each requirement from the context, marked done, partial or missing, with path:line; then each business behaviour no requirement asks for, marked unnecessary, with path:line and what it adds.
2. Findings ordered by severity, each as: requirement — `path:line` — what is wrong — the concrete change.
3. Questions the context leaves open for the ticket author.
4. Prompt additions: each suggested line ready to paste, with the unnecessary items it would have prevented. Omit the section when nothing is unnecessary.
No summary of the diff.
</structured_output_contract>
```

## 4. Report

Codex is sometimes wrong, so open each finding's path:line and drop the ones that don't hold. Report two sections, Code and Business, most severe first, each finding with its `path:line`; from the business checklist keep only partial, missing and unnecessary items, and pass the open questions and prompt additions on as they are. Leave the code unchanged; the user picks what to fix.
