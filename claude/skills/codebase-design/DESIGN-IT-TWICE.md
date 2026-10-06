# Design It Twice

When the user wants to explore alternative interfaces for a chosen deepening candidate, use this parallel sub-agent pattern. Based on "Design It Twice" (Ousterhout) — your first idea is unlikely to be the best.

Uses the vocabulary in [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**, **leverage**.

Interface design is taste-sensitive work: run these sub-agents on Opus-5 (see `subagent-use`).

## Process

### 1. Frame the problem space

Before spawning sub-agents, write a user-facing explanation of the problem space for the chosen candidate:

- The constraints any new interface would need to satisfy
- Its dependencies and which category they fall into (see [DEEPENING.md](DEEPENING.md))
- A rough illustrative Go sketch to ground the constraints — not a proposal, just a way to make them concrete

Show this to the user, then immediately proceed to Step 2. The user reads and thinks while the sub-agents work in parallel.

### 2. Spawn sub-agents

Spawn 3+ sub-agents in parallel. Each must produce a **radically different** interface for the deepened module.

Prompt each with its own technical brief — file and package paths, current coupling, dependency category from [DEEPENING.md](DEEPENING.md), what sits behind the seam. The brief is independent of the user-facing explanation from Step 1. Give each a different design constraint:

- Agent 1: "Minimize the exported surface — 1–3 entry points max. Maximise leverage per entry point."
- Agent 2: "Maximise flexibility — support many use cases and extension. Functional options, composable types."
- Agent 3: "Optimise for the most common caller — make the default case a single call with a useful zero value."
- Agent 4 (if applicable): "Design around injected ports for the cross-network or third-party dependencies."

Include the [SKILL.md](SKILL.md) vocabulary in every brief, plus `golang-conventions` and the project's own domain vocabulary (`CONTEXT.md` or `CLAUDE.md`, if present), so the designs name things consistently.

Each sub-agent outputs:

1. The interface — exported identifiers and signatures, plus sentinel errors, zero-value behaviour, goroutine-safety, and lifecycle constraints
2. A usage example showing a real caller
3. What the implementation hides behind the seam
4. Dependency strategy and adapters (see [DEEPENING.md](DEEPENING.md))
5. Trade-offs — where leverage is high, where it's thin

### 3. Present and compare

Present designs sequentially so the user can absorb each one, then compare them in prose. Contrast by **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**.

Then give your own recommendation: which design is strongest and why. If elements from different designs combine well, propose a hybrid. Be opinionated — the user wants a strong read, not a menu.
