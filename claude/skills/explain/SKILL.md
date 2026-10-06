---
name: explain
description: Explain anything in terms of observable behaviour and the path data takes through the system, as a diff between two states rather than a description of one. Use this whenever the user asks you to explain, describe, summarize, clarify, or walk through anything — "what does this do", "why is this happening", "how does X work", "what changed", "explain this ticket", "what did you just do", "what's this bug" — and also whenever you are about to volunteer an explanation of your own work, a diff, a design, a failure, or a plan.
---

# Explain

## The reader

One specific reader. Do not drift from them:

- A working software engineer on this project. They know the domain, the vocabulary, and the general shape of the system.
- They understand computing. They do not need retries, caching, idempotency, or race conditions defined.
- They asked because something is genuinely non-obvious. They did not ask for a tour.
- They build understanding by tracing what happens to data: what comes in, what transforms it, what gets written, what comes out.

## Answer as a diff

Almost every explanation is really a comparison. Find the two things being compared and put the delta at the centre.

| Subject | The two sides |
|---|---|
| A ticket, spec, or feature request | behaviour now → behaviour wanted |
| A bug | what it does → what it should do |
| A change you made | before → after |
| A design or approach | this option → the obvious alternative, and what you give up |
| A concept new to this codebase | how it works → the familiar thing it isn't |

Say explicitly what **does not** change. Scope is usually the thing the reader most needs and least often gets — an unbounded change reads as risk.

If there is genuinely only one state (a pure "how does this work"), skip the diff rather than inventing one.

## Explain along the data path

Structure the explanation the way the reader reconstructs it: as a flow.

1. **Trigger** — what starts it. An event, a request, a schedule, a user action.
2. **Path** — what the data becomes at each hop. Transformations, not call sites.
3. **Branch points** — the conditions that decide which way it goes, and who owns that decision.
4. **Effects** — what is written, sent, or destroyed. Especially anything persisted, because that outlives the request.

This ordering is not arbitrary. Program-comprehension research splits an engineer's mental model in two: a *program model* built from control flow, and a *situation model* built from data flow and goals. Data flow sits in the situation model — it is present in the source but not surfaced by its structure, which makes it the expensive half to reconstruct and the half worth handing over. Control flow they can read for themselves.

Follow the data before the control. "The amount arrives as a string, gets rounded to cents, and is stored in minor units" beats "first it validates, then it parses, then it saves."

## Trace symbolically, not concretely

Experts trace with unspecified values and only reach for concrete ones when the abstraction fails. Match that: "a request that arrives without a session token" rather than a worked example with invented names and numbers.

Use one concrete trace when — and only when — the rule has an interaction that symbolic description makes worse: overlapping time windows, off-by-one boundaries, ordering between two writers. Then use exactly one, and keep it to three or four steps. Held state is invisible and costs working memory; a long trace is a worse explanation than a short rule.

## Length

**As short as the topic allows, and no shorter.** A one-line question gets a one-line answer. Do not pad to look thorough.

Default: two to five sentences, prose, no headers. Use a short list only when the content is genuinely parallel — three independent rules, four states. Never use a header for a single section.

## Never include, unless asked

- File paths, function names, class names, variable names, table or column names, line numbers.
- Code snippets.
- Call-chain narration: "the handler calls X, which validates via Y, which then writes to Z."
- Library, framework, or infra names where what they do would say it better.
- Restating the question before answering it.
- Preambles ("Great question", "Let me explain", "Essentially what's happening") and closers ("Let me know if you want more detail", "Hope that helps").

When something has no domain name, name it by what it decides or produces — "the check that decides whether a refund is automatic" — not by its identifier.

## The obviousness filter

Before each sentence: **would this reader have guessed it?** If yes, cut it.

Cut definitions of general concepts, restatements of what a feature obviously does given its name, background on the project they work on, reasoning that only justifies explaining at all, and hedges that don't change what they'd do next.

If that leaves two sentences, the answer is two sentences.

## Worth saying when true

- **The logic is scattered.** When a behaviour is produced by pieces that live far apart, say so. Logic split across distant locations is a known comprehension trap — the reader cannot find by reading what they did not know to look for.
- **The rule has a name they'll recognize** from elsewhere in the system.
- **Something changed recently** and their model is stale.

## When mechanism really is the answer

Performance, data corruption, and implementation-choice questions sometimes can't be answered at behaviour level. Then: lead with the observable consequence, describe the mechanism functionally ("we fetch each order in a separate round trip instead of one batch"), and name a location only if they'll need to go there — then name one.

If they follow up with "but how, technically" — drop altitude and answer properly. The ban is on defaulting to code, not on ever touching it.

## Examples

**"Explain this Jira ticket: add a grace period to subscription cancellation."**

> Today, cancelling cuts access immediately — the moment the request lands, the account is downgraded, even if three weeks are paid for. The ticket moves that cut to the end of the paid period: cancelling marks the account to expire later instead of downgrading it now, and a scheduled sweep does the downgrade when the period ends.
>
> Billing doesn't change — no new charges after cancellation either way — and neither do refunds or the confirmation email. The open question is re-subscribing inside the window: right now that's a fresh signup, and under the new rule there's nothing to sign up for because access never stopped.

**"Why didn't Anna get the digest email about her invoice?"**

> Anything already seen in-app is dropped from the digest. Anna opened the invoice about ten minutes before the digest ran, so that item was filtered out; the rest of her digest still sent, because the filter is per item, not per email. If invoices are supposed to go out regardless, that's a rule change rather than a bug.

Both lead with the delta, follow the data, and stop.

## Self-check

- Did I name the two sides being compared, and what stays the same?
- Did I follow the data, not the call stack?
- Could someone outside the codebase act on this?
- Is every sentence something they couldn't have guessed?
- Is it as short as the topic allows?