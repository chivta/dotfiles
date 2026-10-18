## General Guidance

- Follow YAGNI (You Aren't Gonna Need It) principle unless told otherwise.
- Don't be scared to propose radical changes if they can meaningfully benefit our work.
- For any volatile information, always perform a web search before making assumptions. Volatile information includes:
  - Versions — language runtimes, libraries, tools; always verify the current LTS/stable release
  - Non-core features — peripheral or ecosystem-adjacent functionality that may have been deprecated, renamed, or moved (contrast: "PostgreSQL stores data" is stable fact; "PostgreSQL supports X extension syntax" is not)
  - Cloud/SaaS resource limits and pricing — instance types, quotas, free tier limits change frequently
- A question is a request for an answer, not for changes. Even if action is trivial. If the message opens with "how hard would it be", "can we", "why does", "should we", "is it possible", "can X do Y", "doesn't X do Y", "can't we do X" or otherwise asks rather than instructs: answer it, and do not edit files.
- Ignore bugs unless I named the bug, a QA check or a test or verification run hit it, or it is highly critical (data loss, a security hole, a production outage). Ignoring means no fix, no plan item, no line in a subagent prompt and no mention in reports. A failure found only by reading code, such as a type assertion that panics on input nobody is known to send, does not qualify.
- Plans always go to the local .claude directory unless the user requests otherwise.

## Project conventions

- Follow the project's existing conventions in everything: naming, file layout, error handling, libraries, tests, code style. Before any design decision (where a variable lives, what a method is called, which helper to use), find how the codebase already does it and do the same. Project conventions take precedence over the defaults in this file.
- When the codebase does the same thing in competing ways, follow the approach used in newer files (check file age with `git log`). In a small project, or when file age doesn't settle it, name the competing approaches and let the user choose.
- In a legacy file, write new code the newer way even though it breaks from the surrounding code, then suggest migrating the whole file to it.
- Migrations are immutable and should be treated like a commit rather than current state. Never delete or modify an existing migration (and its comments) that has likely already run in production (it's on origin/stage, origin/main or similar); add new migration(s) to change the schema instead.
- Never touch production, live databases, remote servers. If a task requires remote access or production data, stop immediately and ask for instructions.
- Input validated at system boundaries only (HTTP handlers, queue consumers). Internal functions trust their callers.
- Prefer named constants over hardcoded values. A magic number or string used even once should be a constant — it makes the intent visible, shows every place the value is used, and makes changes trivial.

## Common abbreviation

- `dc` - docker-compose
- `ks` - kubectl
- `tf` - the fuck
- `cc` - claude code (agent)
- `rn` - right now

## Writing

Applies to every message and document.

- Keep it as short as the topic allows: a one-line question gets a one-line answer. Don't pad to look thorough.
- Write prose by default. Use a list only when the items are genuinely parallel, and never put a header over a single section.
- Before each sentence, ask whether the reader would have guessed it; if so, cut it. For me that means no definitions of general computing concepts (retries, caching, race conditions), no background on my own project, no restating the question, no preambles ("Great question", "Let me explain") or closers ("Hope that helps"), and no hedges that don't change what I'd do next.
- If I express an assumption and expect you to validate it, rate it with one of these words:
  - "wrong": below 30% correct
  - "partially": 30–59%
  - "mostly": 60–79%
  - "exactly": 80% and above
- Always answer only what's explicitly asked; add other information only if it's directly related.
- Always include important caveats unless they're trivial, obvious or don't necessarily require attention. Important caveats count as directly related.
- Delete trailing -ing clauses that carry no information: "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Expand with a real fact or drop them.
- Never place a dot or comma right at the end of a piece of text I'm likely to copy (url, path, function name); always add whitespace.

## Delegation

In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.

## Containers and Local Development

`docker-compose` is for local development only. It is usually not used for deployment.

Every service's Dockerfile has distinct named stages:

- **Dev stage**: minimal base image. Runs with a hot-reload tool appropriate to the language/framework. Source code is bind-mounted; the image does not need to be rebuilt on code changes.
- **Builder stage**: compiles/bundles the production artifact.
- **Production stage**: starts from the smallest viable base for the runtime (distroless, `scratch`, minimal Alpine, or a slim official runtime image). Contains only the final artifact. No build tools, no source code. Use a base with a shell/`wget` when a healthcheck needs it.

## Commits

Always assume commits might be cherry-picked or rebased to another branch, so commit atomic pieces of work right after finishing it.
Commits name kfinished atomic piece of work in this style only: ref/feat/fix/chore/docs: <one imperative sentence describing piece of work>
Never write paragraph describing commit.
Never add 'Co-Authored-By:' to commit message.

Good examples:

"fix: added ScheduleRepository nil reference guard"
"chore: fixed linter"
"ref: ScheduleRepository -> FacebookScheduleRepository"
"feat: added audience model"

## Comments

- Keep comments and docs up to date with code changes. If any changes obsolete a comment or doc, update it.
- Keep comments concise and only explain unusual or non-obvious behavior. Don't restate the code. Don't explain the obvious. Don't explain what the code does, explain why it does it that way. 95% of cases do not need comment.
