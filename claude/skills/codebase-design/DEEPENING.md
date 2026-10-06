# Deepening

How to deepen a cluster of shallow Go packages safely, given its dependencies. Assumes the vocabulary in [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**.

## Dependency categories

Classify the candidate's dependencies. The category determines where the seam goes and how the deepened module is tested across it.

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable: merge the packages, test through the new export line with plain table tests. No `interface` declaration, no adapter, no seam beyond the export line itself. Most domain logic belongs here — if it doesn't, that's usually the finding.

### 2. Runnable locally

The real dependency can run in the test process or a container: `httptest.Server`, `testcontainers` or a docker-compose Postgres, `fstest.MapFS`, `t.TempDir()`, an embedded queue. Test the deepened module against the real thing. Any seam here is **internal** — don't push a port out through the module's interface just because a test needed a stand-in.

This is the default for repositories. A repository tested against real Postgres catches what a fake never will, and the SQL is the part worth testing.

### 3. Injected port

Anything you can't or shouldn't run in tests: third-party services (Stripe, Telegram, an LLM API), other services across the network, wall-clock time, randomness. The consumer declares a narrow, unexported `interface` naming exactly what it needs; production wires the real adapter, tests pass a hand-written fake. The logic stays in one deep module even though it's deployed or vendored across a network.

Recommendation shape: *"Declare the port at the consumer, wire an HTTP adapter in `main`, and a fake in the test — so the logic sits in one deep module even though it crosses a network."*

## Seam discipline

- **Two adapters or no seam.** Production adapter + test fake justifies a port. A single implementation with an `interface` sitting next to it is indirection, not a seam — delete it and return the concrete struct.
- **The port belongs to the consumer, not the implementation.** It is exactly as wide as the caller needs. A port that mirrors every method of the concrete type is the implementation's shape leaking upward.
- **Internal seams stay internal.** A deep package can have unexported seams its own tests use. Don't export one to make a test easier — that trades permanent interface width for temporary convenience.
- **`internal/` is a real seam.** Where the compiler can enforce that nothing outside the module imports an implementation detail, use it rather than relying on discipline.

## Testing strategy: replace, don't layer

- Old tests against the shallow packages become waste once tests exist at the deepened module's interface — delete them. Keeping both means every change costs two edits and the old ones pin the shape you just removed.
- Write new tests in `package foo_test`. The **interface is the test surface**; the external test package makes the compiler enforce that.
- Assert on observable outcomes through the interface — returned values, sentinel errors via `errors.Is`, effects visible through the module's own reads. Not unexported state.
- Tests should survive internal refactors. If a test has to change when the implementation changes, it's testing past the interface.
