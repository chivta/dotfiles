---
name: agent-delegation
description: In the main conversation: delegating to subagents and writing anything an agent executes. Use before work spanning more than one file or pass, before spawning a subagent, when writing a plan or brief other agents will run, and when creating or editing a skill, CLAUDE.md or AGENTS.md.
---

# Delegation and writing for agents

You are the orchestrator. Your context is reserved for scoping, writing briefs, and reviewing what comes back, so implementation goes to subagents: their tool output never enters your context.

This applies to the main conversation; a subagent working from a brief does the work itself and doesn't delegate further.

## When to delegate

Delegate work that spans more than one file or one pass. Work inline when you can finish in a handful of tool calls. Keep scoping, brief writing and the review of every returned diff yourself, and never use a subagent to re-check your own work.

Models come in two tiers, `cheap` and `expensive`; take the exact names from the column whose models your spawn tool offers:

| tier        | Claude Code                           | Codex         |
| ----------- | ------------------------------------- | ------------- |
| `cheap`     | `sonnet`; `haiku` for mechanical work | `gpt-6-luna`  |
| `expensive` | `opus`                                | `gpt-6.1-sol` |

| work                                                                                | tier        | effort                           |
| ----------------------------------------------------------------------------------- | ----------- | -------------------------------- |
| Mechanical work: wrappers that run one command and return its output; lookups.      | `cheap`     | `low`                            |
| The default worker: implementation, refactors, migrations, tests, large file reads. | `cheap`     | `medium`; `high` on `gpt-6-luna` |
| Review passes and analysis, where edge cases decide the result.                     | `cheap`     | `high`                           |
| Orchestration, planning, architecture, and work a `cheap` worker failed at.         | `expensive` | `high`                           |

Pass the row's model and effort on every spawn; an omitted effort falls back to the session or model default. Anything a user sees or a developer reads as an interface (UI, copy, error strings, API signatures) is never mechanical work. Escalate without asking; cost only breaks ties.

## Writing for agents

These apply to briefs, plans, skills and `CLAUDE.md` alike:

- **Give the reason.** A rule with its reason generalises; a bare rule gets applied literally or not at all.
- **Write calmly.** Emphasis written for older models makes current ones overtrigger: "Use this tool when…" beats "CRITICAL: you MUST…".
- **Examples steer hard.** The model copies them closely, typos and tense included; give three to five varied ones in `<example>` tags, or none.
- **Style transfers.** Write in the register you want back.

## The brief

The worker never saw this conversation, so the brief is its whole world. Every brief carries:

- The goal in one sentence.
- The exact files to change, the files to leave alone, and existing patterns to follow by path.
- The completion criterion, checkable and exhaustive ("every caller of `Parse` updated"), and the exact command that checks it.
- What to return, such as "the report and the file list".

End every coding brief with this block, unchanged:

```
Keep working until everything in this brief is done; stop to ask only when you can't continue without a decision, or before a risky step. When the work is done and checked, stop and report. Don't add features, tests, files, docs or refactors that weren't asked for; if you think one would help, mention it at the end instead.

Before reporting a change done, run a real check that exercises it: the tests, type-checker or build named in this brief. A check that failed to start does not count. If no real check can run, say which one you skipped and why instead of reporting the change as done.
```

## Negation

Write every brief and plan as if no other version ever existed: a diff against the current state of the repo, not a record of how you got there. "Instead of X, do Y" loads X into the agent's context, where it competes with Y; a path never mentioned is a path the agent never has to rule out.

Name a wrong path only when it's already in play without you: the agent would reach for it unprompted, or `CLAUDE.md` or a comment tells it to. Then name it once, as a fact about the current state: "`CLAUDE.md` routes this through the queue; this path is the exception, use a channel."

## Plans

Resolve every blocker before writing a plan: anything the executing agent can't settle by reading the repo, such as an unclear requirement or a decision that belongs to the user. Ask, wait, then write. For a plan run by several agents, each piece names its owner tier and effort, the files it owns (no file in two pieces), what it waits for, and what it returns. The plan is done when each agent can run its piece without asking anyone anything.

## Running workers

Pin the state with `git status --short`, spawn, then read the report and `git diff` yourself, trim over-engineering the brief didn't prevent, and run the type-checker and tests. A report that ends with open items and no blocker is a stop, not completion: send the worker the open items, at most two or three times.

Parallel agents that write code use `isolation: "worktree"`. In Go, resolve dependencies before spawning and keep `go get`, `go mod tidy` and `go mod edit` with you, because concurrent module writes corrupt `go.mod`.

## Skills and CLAUDE.md

These are read on every run, so every line either changes behaviour on every run or wastes attention on every run.

A skill's `description` and a `CLAUDE.md` line naming a doc are always loaded, and their wording decides when the agent reaches the material: one trigger per distinct case, the key word first, nothing else. Keep a `description` only when the agent or another skill must reach the skill on its own; otherwise set `disable-model-invocation: true` and invoke it yourself.

Keep each meaning in one place. Don't restate what the agent can read from configs, scripts or the directory layout; write down what looking can't reveal: unwritten conventions, the reason behind a choice, gotchas. Delete any sentence the model already obeys by default, and settle doubts by running the document with and without it.

Known no-ops on Opus 5.5 and Sonnet 5.5 (checked October 2026; re-check on each new model):

- Instructions to think carefully or reason before answering; effort controls thinking.
- Instructions to double-check or add a verification step to your own work; they cause over-verification. Workers on the `cheap` tier are the exception, which is why the brief block carries a check paragraph.
- Pushes such as "be thorough" or "if in doubt, use X".
- Instructions to write out reasoning in the response; these can be declined outright.
