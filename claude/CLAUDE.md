## General Guidance

- Keep things simple. Channel "yagni" energy unless told otherwise.
- Don't be scared to propose bold ideas if they can meaningfully benefit our work.
- Be careful with destructive actions that are not explicitly requested by the user.
- Prefer unit tests and manual/agent-driven testing (e.g. with curl) during development; avoid building e2e suites, heavy CI pipelines, or test automation infrastructure unless explicitly requested.
- Don't scaffold testing frameworks, CI configs, or test runners proactively — favor targeted unit tests for the specific logic being changed.
- If a broader test system (e2e, integration harness, CI) would meaningfully speed up development, propose it explicitly and wait for confirmation before building it.
- Keep comments up to date! When making changes, it's important to keep things in sync.
- If recent changes obsolete CLAUDE.md or any other docs, say so and propose updating it to user.
- For any volatile information, always perform a web search before making assumptions. Volatile information includes:
  - Versions — language runtimes, libraries, tools; always verify the current LTS/stable release
  - Non-core features — peripheral or ecosystem-adjacent functionality that may have been deprecated, renamed, or moved (contrast: "PostgreSQL stores data" is stable fact; "PostgreSQL supports X extension syntax" is not)
  - Cloud/SaaS resource limits and pricing — instance types, quotas, free tier limits change frequently
- Avoid piping to python for parsing json, use `jq` util instead.
- Prefer monorepo when possible: single repo for frontend, backend, cronjob workers etc.
- A question is a request for an answer, not for changes. If the message opens with "how hard would it be", "what are your thoughts", "why does", "should we", "is it possible", "can X do Y", "doesn't X do Y", "can't we do X" or otherwise asks rather than instructs: answer it, and do not edit files.
- Always answer only what's explicitly asked, only add additional info if it's directly related.
- Ignore bugs unless I named the bug, a QA check or a test or verification run hit it, or it is highly critical (data loss, a security hole, a production outage). Ignoring means no fix, no plan item, no line in a subagent prompt and no mention in reports. A failure found only by reading code, such as a type assertion that panics on input nobody is known to send, does not qualify.
- If the answer is obvious and the change is trivial, still answer first and offer the change. Ask before making it.
- Always warn user before commiting to running long-running commands like `make build`, `docker-compose build`.
- Plans always go to local .claude directory unless user requests the otherwise.

## Project conventions

- Follow the project's existing conventions in everything: naming, file layout, error handling, libraries, tests, code style. Before any design decision (where a variable lives, what a method is called, which helper to use), find how the codebase already does it and do the same. Project conventions take precedence over the defaults in this file.
- When the codebase does the same thing in competing ways, follow the approach used in newer files (check file age with `git log`). In a small project, or when file age doesn't settle it, name the competing approaches and let the user choose.
- In a legacy file, write new code the newer way even though it breaks from the surrounding code, then suggest migrating the whole file to it.
- Never modify old migrations that have already ran in production. This applies to comments too, treat old migrations as immutable. If a migration needs to be changed, create a new one that does the change.

## Common abbreviation

- `dc` - docker-compose
- `ks` - kubectl
- `tf` - what is
- `cc` - claude code (agent)

## Writing

Applies to every message and document.

Write to me like a competent colleague who already has the context. Lead with the answer: no throat-clearing openers, no restating my question back, no announcing what you're about to do. Keep it as short as the topic allows — a one-line question gets a one-line answer, and padding to look thorough is worse than being brief. Prefer concrete claims to vague declaratives; if you name a cause, name the specific one, and if you don't know, say so instead of hedging in every direction. Never fill a gap with a plausible-sounding number, name, benchmark, or example. Active voice with real actors doing things; inanimate subjects don't perform human actions. Drop the LLM cadence: "it's not X, it's Y" contrasts, self-answered rhetorical questions, negative listings ("this isn't about speed, or cost, or scale"), one-sentence paragraphs for drama, em dashes as the default connective, and adverb or emphasis crutches ("genuinely", "incredibly", "it's worth noting", "the key insight here"). Don't end with a recap of what you just said, a moral, or an offer to go deeper. Prose by default; bullets only when the content is actually parallel, headers only when there's more than one real section. When describing a change, an option, or a proposal, frame it as a diff: what holds now, what would hold after, and what stays the same.

- No em dashes. End the sentence or use a comma. Reaching for parentheses instead is the same tell.
- Colons only before a list or example, never as a mid-sentence connector.
- Sentence case headings, straight quotes, no decorative emoji. Don't bold every proper noun.
- A bold lead-in must be followed by new detail, not a restatement of itself.
- Say what it does, not how it feels. Name the mechanism, the number, or the command. If a sentence could appear unchanged in another project's docs, cut it.
- Active voice. Name the actor.
- Cut adverbs, or replace the weak verb they prop up.
- Cut filler ("in order to", "it is important to note that") and stacked hedges.
- No chatbot phrases, no sycophancy. Not "Great question", not "Let me know if".
- One idea per sentence. Vary the rhythm, short then longer.
- Have opinions. React to the facts instead of listing pros and cons neutrally.
- Cut puffery. Not "pivotal moment", "testament to", "evolving landscape", "indelible mark", "deeply rooted". State what happened.
- Name the source or delete the claim. "Experts believe", "industry reports suggest", "some critics argue" attribute to nobody. Listing outlets without saying what they said is the same move.
- Delete trailing -ing clauses that carry no information: "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Expand with a real fact or drop them.
- No promotional adjectives: "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit".
- No formulaic contrast. "Despite challenges, X continues to thrive" says nothing. Give the specific fact.
- Replace AI vocabulary with plain words: additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape, pivotal, showcase, tapestry, testament, underscore, vibrant.
- Prefer the plain word. "utilize" is "use", "leverage" is "use", "facilitate" is "help", "numerous" is "many", "in the event that" is "if".
- Just say "is" or "has". Not "serves as", "stands as", "boasts", "features".
- No "not just X, but Y". State the point directly.
- Use the natural number of items. Three is not a target.
- Pick one term and repeat it. Cycling through protagonist, main character, central figure reads as thesaurus work.
- No false ranges. "From X to Y" works only when X and Y sit on a real scale. Otherwise list the items.
- No abstract metaphor nouns: substrate, wedge, vector, locus, vantage, nexus, primitive, harness, surface, bedrock, scaffolding, modality, paradigm, gold-plating, ratchet, evacuate, endgame, north star, flywheel. Substrate is "base", vector is "method", gold-plating is "more than the job needs", evacuate is "move out".
- No cutoff disclaimers. "While specific details are limited" means find the source or drop the claim.
- No generic conclusions. "The future looks bright" stands in for a plan you should state instead.
- Acknowledge complexity instead of flattening it. "Impressive but unsettling" beats "impressive".
- First person is fine when it fits. It is not unprofessional.
- Let some mess in. Flawless parallel structure looks machine-made.
- Last pass on anything long: ask what makes this obviously AI generated, then fix what is left.
- Never place a dot right at the end of the path always add a whitespace before dot.

## Blast radius

- Never touch production, live databases, remote servers unless explicitly told to. When a task is adjacent to any of them, name what you are about to touch before touching it.

## Delegation

- Default to spawning a subagent. Do the work inline only when writing the prompt and spawning an agent would take more work than the work itself.

## Containers and Local Development

`docker-compose` is for local development only. It is usualy not used for deployment.

Every service's Dockerfile has distinct named stages:

- **Dev stage**: minimal base image. Runs with a hot-reload tool appropriate to the language/framework. Source code is bind-mounted; the image does not need to be rebuilt on code changes.
- **Builder stage**: compiles/bundles the production artifact.
- **Production stage**: starts from the smallest viable base for the runtime (distroless, `scratch`, minimal Alpine, or a slim official runtime image). Contains only the final artifact. No build tools, no source code. Use a base with a shell/`wget` when a healthcheck needs it.

## Configuration

All config comes from environment variables, loaded into a typed object validated on startup — the process exits immediately if anything is required and missing, or present and invalid.
A `.example.env` documenting every variable is committed.
All variable should have "value" as it's value.
Never add quotes around variable value unless neccessary.
Every env requiring real value for starting service locally should have "replace" in it's value.
The real `.env` is gitignored. Secrets are never logged.
Service should be immediately startable and all variables passing validation after copying .env.example into .env and replacing all "replace" variables. (required DB seed is an exclusion)

## Error Handling

Errors are typed and carry what's needed to produce a correct response: a status and a machine-readable code, never a human message. Human messages live in the frontend translation map, keyed by that code.

Log an error once, where it's handled — not at every level it passes through.

## Security Defaults

- Secrets never committed in plaintext. Use envelope encryption (e.g. SOPS) for secrets that must live in version control.
- Input validated at system boundaries only (HTTP handlers, queue consumers). Internal functions trust their callers.
- Production containers run as non-root with a read-only filesystem and all Linux capabilities dropped.
- Cookies set with `Secure` and `HttpOnly` in production.

## Constants

Prefer named constants over hardcoded values. A magic number or string used even once should be a constant — it makes the intent visible, shows every place the value is used, and makes changes trivial. Hardcoded literals scattered across the codebase are a maintenance liability.

## Commits: every commit, always

Always assume commits might be cherry-picked or rebased to another branch, so commit atomic pieces of work right after finishing it.
Commits name finished atomic piece of work in this style only: ref/feat/fix/chore/docs: <one sentence describing piece of work>
Never write paragraph describing commit.
Never add 'Co-Authored-By:' to commit message.

Good examples:

"fix: added ScheduleReposetory nil reference guard"
"chore: fix linter"
"ref: ScheduleRepository -> FacebookScheduleRepository"
"feat: addded audience model"

## Frontend

React SPA with TypeScript. Communicates with the backend over REST only. No CSS framework — inline styles. No global state management library unless there is a concrete need. React Context for narrow, well-defined cross-cutting concerns only (e.g. locale).

All user-facing strings live in a single translation map. Components contain no hard-coded text, including error messages. Backend error codes map to translation keys in one place.
