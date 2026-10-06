---
name: codebase-design
description: Shared vocabulary for designing deep Go packages and types. Use when the user wants to design or improve a package's interface, find deepening opportunities, decide where a seam goes, make Go code more testable or AI-navigable, or when another skill needs the deep-module vocabulary.
---

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small exported surface, placed at a clean seam, testable through that surface. Use this language wherever Go code is designed or restructured. The aim is leverage for callers, locality for maintainers, and testability for everyone.

This skill decides **shape**: where seams go, how deep a module is, what sits behind an interface. Go **mechanics** — naming, libraries, sentinel errors, wiring syntax, logging — live in `golang-conventions`. When the two seem to disagree, this one wins on structure.

## Glossary

Use these terms exactly — don't substitute "component," "service," "API," or "boundary." Consistent language is the whole point.

**Module** — anything with an interface and an implementation. Deliberately scale-agnostic: a function, a struct with methods, a package, or a layer-spanning slice. In Go the default unit is the **package**. _Avoid_: unit, component, service.

**Interface** — everything a caller must know to use the module correctly. Bigger than the Go `interface` keyword: the exported identifiers and their signatures, plus the sentinel errors it can return, the zero-value behaviour, goroutine-safety, ordering and lifecycle constraints (must `Close`, must call after `Start`), required config, and performance characteristics. _Avoid_: API, signature — both too narrow.

**Implementation** — everything below the export line: unexported types, funcs, fields, and anything under `internal/`. Distinct from **Adapter**: a thing can be a small adapter with a large implementation (a pgx-backed repo) or a large adapter with a small implementation (an in-memory fake).

**Depth** — leverage at the interface: how much behaviour a caller (or test) exercises per unit of interface it has to learn. **Deep** = lots of behaviour behind a small surface. **Shallow** = the exported surface is nearly as complex as what's behind it.

**Seam** _(Michael Feathers)_ — a place where you can alter behaviour without editing in that place; the *location* at which a module's interface lives. Where to put the seam is its own decision, distinct from what goes behind it. In Go a seam is usually a package export line or a consumer-declared `interface`. _Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter** — a concrete type satisfying an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside).

**Leverage** — what callers get from depth: more capability per unit of interface learned. One implementation pays back across N call sites and M tests.

**Locality** — what maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place instead of spreading across callers. Fix once, fixed everywhere.

## Deep vs shallow

Go gives you a real, compiler-enforced export line. Depth is the ratio across it.

```
package tokens                     package tokens
┌──────────────────────────┐       ┌───────────────────────────────────────┐
│ Issue(ctx, UserID) (T,e) │       │ NewSigner, Signer.Sign, Signer.Key,   │
│ Verify(ctx, T) (Claims,e)│       │ Claims, Encode, Decode, ParseHeader,  │
│ ErrExpired, ErrRevoked   │       │ ClockSkew, ValidateAud, ErrBadAlg ... │
├──────────────────────────┤       ├───────────────────────────────────────┤
│ signing, key rotation,   │       │ each one a thin wrapper the caller    │
│ revocation, skew, claim  │       │ has to sequence correctly itself      │
│ validation — all hidden  │       │                                       │
└──────────────────────────┘       └───────────────────────────────────────┘
          DEEP                                     SHALLOW
```

A shallow package pushes sequencing onto every caller. When the rule changes you edit N call sites instead of one.

When designing an interface, ask:

- Can I export fewer identifiers?
- Can I simplify the parameters — fewer of them, or a single options struct with a useful zero value?
- Can I move more of the sequencing inside?

## Principles

- **Depth is a property of the interface, not the implementation.** A deep package can be internally composed of small, swappable parts — they just aren't exported. A module can have **internal seams** (unexported, used by its own tests) as well as the **external seam** at its export line.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If it reappears across N callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. Prefer `package foo_test` — it forces you to test through the export line. Reach for in-package tests only for genuinely internal seams.
- **One adapter means a hypothetical seam. Two adapters means a real one.** Don't declare an `interface` unless something actually varies across it. Production impl + test fake counts as two; production impl alone does not.
- **Accept interfaces, return structs.** Callers get a concrete type with real methods and fields — full depth, no guessing. Dependencies come in as narrow interfaces the consumer declares itself.
- **Errors are part of the interface.** A caller can't use the module correctly without knowing which sentinel errors cross the seam. Export them, document them, and keep the set small — leaking a wrapped `pgx.ErrNoRows` past the export line is a depth failure, not just a style one.

## Designing for testability

1. **Accept dependencies, don't construct them.**

   ```go
   // Testable: the seam is the parameter.
   func NewOrderService(payments PaymentGateway) *OrderService

   // Hard to test: the dependency is welded in.
   func NewOrderService() *OrderService {
       return &OrderService{payments: stripe.New(os.Getenv("STRIPE_KEY"))}
   }
   ```

2. **Declare the dependency interface at the consumer, narrow.**

   ```go
   // In the service package — exactly what this service needs, nothing more.
   type paymentGateway interface {
       Charge(ctx context.Context, amount domain.Money) (domain.ChargeID, error)
   }
   ```

   The pgx- or Stripe-backed type in its own package satisfies it implicitly and never imports it. The interface stays as wide as the caller needs, not as wide as the implementation happens to be.

3. **Return results, don't mutate arguments.**

   ```go
   // Testable: assert on the return value.
   func Discount(cart domain.Cart) domain.Discount

   // Hard to test: assert on state somewhere else.
   func ApplyDiscount(cart *domain.Cart)
   ```

4. **Small surface area.** Fewer exported identifiers = fewer tests. Fewer params = simpler setup. Useful zero values and functional options beat five-argument constructors.

5. **Hand-write fakes.** A fake satisfying a 2-method consumer interface is ~15 lines and reads in the test file. Generated mock frameworks add a build step and a second vocabulary for no depth. If a fake is painful to write, the interface is too wide — fix the interface.

## Relationships

- A **Module** has exactly one **Interface** — the surface it presents to callers and tests.
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.

## Rejected framings

- **Depth as ratio of implementation-lines to interface-lines** (Ousterhout): rewards padding the implementation. Use depth-as-leverage instead.
- **"Interface" as the Go `interface` keyword**: too narrow, and the most common confusion here. A package with zero `interface` declarations still has an interface — everything exported, plus errors, lifecycle, and concurrency rules.
- **"Boundary"**: overloaded with DDD's bounded context. Say **seam** or **interface**.
- **A `Repository` interface next to its one implementation**: that's not a seam, it's indirection. Return the concrete struct; declare the interface at the consumer if and when a second adapter exists.
- **A fixed layer count as the answer**: handler/service/repository/domain is a common *result* of applying these rules to an HTTP service, not the rule itself. Layers that turn out to be pass-throughs fail the deletion test like anything else.

## Going deeper

- **Deepening a cluster given its dependencies** — see [DEEPENING.md](DEEPENING.md): dependency categories, seam discipline, and replace-don't-layer testing.
- **Exploring alternative interfaces** — see [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md): parallel sub-agents design the interface several radically different ways, then compare on depth, locality, and seam placement.
