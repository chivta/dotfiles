---
name: subagent-use
description: Read before any work spanning more than one file or one pass, before spawning a subagent, before bulk implementation, refactoring, review, test writing, or large file reading, and before writing any plan that other agents will execute. Covers which model each piece gets, how to prompt a worker, and how to run agents in parallel. Default is to delegate, so read this before deciding to work inline.
---

# Delegating work

Spawn a subagent unless writing the prompt costs more than doing the work. That is the whole rule.
Almost everything past a single-file edit clears it.

The reason is context. A subagent's tool output never enters the main context, so a 40k-token
report becomes a paragraph. This holds even for a single call with no parallelism.

## What I do myself

Not everything should leave. Keep:

- Scoping, prompt writing, and the pass over every returned diff. Delegating the scoping defeats
  the point, since a vague prompt produces a diff that costs more to fix than to write.
- One-pass work. A single edit, a single answer, a two-file rename. Spawning here is pure overhead.

Anything a user sees or a developer reads as an interface (UI, frontend components, copy, error
strings, API and function signatures) can be delegated, but only to a model with taste. That means
`sonnet` at minimum, never `haiku`.

## Model roster

| model | use for |
|---|---|
| `haiku` | wrappers that run one command and return its output, mechanical lookups |
| `sonnet` | the default worker: implementation, refactors, migrations, test writing, review passes, analysis, large file reads, UI and API design |
| `opus` | orchestration, planning, architecture, and work the others failed at |

Escalating to a smarter model is always allowed without asking. Cost breaks ties only:
intelligence > taste > cost for anything that ships.

## Running a worker

1. Pin the current state with `git status --short`.
2. Write the prompt. Name the exact files to change, the constraints, and the files to leave alone.
3. Spawn the agent.
4. Read the report and `git diff` yourself.
5. Trim the over-engineering. Workers add defensive branches, wrapper functions, and comments that
   restate the line above. Cut them.
6. Run typecheck and tests.

Treat a review report as evidence, not as a task list. Verify each claim against the code before
acting on it, and drop the ones that are over-engineering.

### Prompt shape

A worker follows a tight prompt and improvises against a loose one. Include:

- The goal in one sentence.
- The exact files to change, and the files to leave alone.
- The existing patterns to follow, by file path.
- What not to build: no new abstractions, no config flags, no tests unless asked.
- How to verify, with the exact command.

## Writing a plan for other agents

A plan that stops at what to build is half a plan. Anything that will be executed by agents has to
say who runs each piece, or whoever picks it up spends the tokens deciding again.

Every piece in the plan names five things:

- **Owner.** `haiku`, `sonnet`, `opus`, or me, with the reason if it is not the obvious one.
- **Files it owns.** An explicit list. Two pieces must never name the same file.
- **What blocks it.** Which pieces must land first, and which run at the same time.
- **Isolation.** `isolation: "worktree"`, or shared tree plus the files nobody may touch.
- **What it returns.** The report, the diff, a file list. An unspecified return gets a retelling.

State the order up front: what runs first, what fans out after it, what waits for the fan-out.
A shared foundation that two pieces both import is one piece, sequenced first, not a thing each
of them creates half of.

## Parallel work

Split whenever the pieces own disjoint files: independent services, per-package refactors,
migrations across many call sites, test backfills, boilerplate. If the pieces can be described
separately, they can run separately. Several agents at once is the normal case.

Each piece needs to be worth its own agent. Three one-line edits are one agent, not three.

Parallel agents that write code use `isolation: "worktree"` so git edits do not collide.

When they must share a tree, give each agent an explicit list of owned paths and forbid touching
anything else. For Go that means no `go get`, `go mod tidy`, or `go mod edit`, since concurrent
module writes corrupt `go.mod`. Resolve dependencies before spawning, and have each agent build
only its own packages.

## Keeping them cheap

Deterministic orchestration beats letting an agent loop. Explicit sequential spawns, or a fixed
list of parallel ones, with a defined finish condition each. An agent left to decide when it is
done burns tokens deciding.

Name what each agent returns. "Return the report and the file list" gets a usable answer. An
unspecified return gets a retelling of everything it did.
