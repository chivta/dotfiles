---
description: 'Question answerable from three files. Reading and answering is inline work; a subagent would only add a hop.'
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

In the main CMS API (cmd/api), when a handler hands an error that is not a not-found to the shared response helpers, what exactly does the client receive and what gets recorded server-side? And what happens when a handler panics instead? Point me to the code that decides each.
