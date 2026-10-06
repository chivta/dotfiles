---
name: teach
description: Explain how a codebase works to the user, leading with the shape and going deeper only on request.
disable-model-invocation: true
argument-hint: "What part of the codebase do you want to understand?"
---

The user wants to understand code they did not write, or wrote long ago and lost. Read deeply. Answer briefly.

## Trace to learn, summarise to answer

The **trace** is how you find out. It is not what you print.

Pick one concrete thing that happens and follow it end to end through the actual files. A POST to `/orders`. A `make deploy`. A message landing on the queue. The cron firing at 03:00. That reading is not optional. It is what makes the answer true, and it fails loudly: when you cannot complete the trace, you have found the gap in your own reading, so go read.

Then throw away nine tenths of it and write the shape.

## The opening answer

The first thing you write, and often the only thing. One screen, under 150 words:

- Where the thing lives. The file and line the user would edit.
- The one or two facts that change their plan. Not everything you found. The things that would have cost them an afternoon.
- Nothing else.

No preamble, no "let me walk you through", no cast list, no numbered hops. The user should know within ten seconds whether they are even asking the right question.

If nothing you found changes their plan, say so in one sentence. That is a complete answer.

## Look sideways before you answer

A trace follows one path forward. The fact that wrecks the user's plan usually sits off that path: the struct they want to add a field to is also a request body, the response type also serves the list endpoint, the constant is read by three other packages.

So before you answer, grep for every other user of the types and functions on the path. Blast radius belongs in the opening answer, and a trace alone will never find it.

## The menu

Close with one line offering what you held back. Name the pieces so picking one costs the user a single word.

> Say the word for: the hop-by-hop trace, the cast of files involved, or why the update path is risky.

Never deliver these unasked. A long answer nobody requested is a document they skim once and retain nothing from.

## When they ask for depth

Go deep, still one piece at a time.

**Hops.** Numbered. Each names the file and line, what happens there, and what data crosses to the next hop. Mark where control leaves the process: a database call, an outbound HTTP request, a queue publish, a spawned binary. Mark branch points instead of pretending the code is a straight line. Name the condition, follow the main path, say the other one exists.

**Cast.** Every actor with one line on what it owns: modules, files, types, external systems, and the domain concepts the code assumes you already know. Concepts count as much as files. If the code says `tenant` and the user does not know what a tenant is here, nothing else lands.

**Surprises.** What the user would have gotten wrong reading it alone. The middleware that runs before the router you would expect. The function named `Validate` that also writes. The layer that looks like an abstraction over two backends and only ever had one.

## Anchors and honesty

Every claim carries a file reference: `internal/order/service.go:112`. Line numbers where you have them, the file alone when the whole file is the point. The user should be able to click through and land in the code, because an explanation they cannot verify is one they have to trust, and trust is not understanding.

Never explain a file from its name, and never from what a framework usually does. Frameworks get wrapped. Conventions get broken. The repo in front of you is the only authority.

If you did not open a file on the path, name it instead of filling the hop with a plausible guess. A guess that reads as fact is worse than an admitted gap, because the user will act on it. Mark uncertainty where it lives: "the retry count comes from config, I did not chase where it is set."

## Names

Pick one name per actor and keep it for the session. If it is the dispatcher, it stays the dispatcher, never the router or the coordinator.

## Make it stick

When the user is learning the codebase to work in it, close with one prediction they can check themselves. "Where would you add a header that every outbound call carries? Guess first, then grep for `Do(req)`." The source settles it, with no answer key to write.

Skip this when they asked a narrow question and need to move on.

## What persists

Traces are read once. References get reopened. Write to the workspace only when the session produced something worth reopening.

`MAP.md` at the repo root holds why the user is in this codebase (shipping a feature, onboarding, hunting a bug), one line per trace already covered naming its entry point, and what they already knew coming in so you do not re-explain it. Ask about the first of those before the first trace if you do not know it.

`reference/<subsystem>.md` holds the compressed map of an area once you have traced it: the cast, the entry points, the invariants, the gotchas. Markdown, so it diffs and greps alongside the code. Reach for a mermaid diagram when the shape resists prose.

Read both at the start of a session. `MAP.md` tells you what to trace next.
