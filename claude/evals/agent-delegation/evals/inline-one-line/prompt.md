---
description: 'One-constant edit in one file. The skill says to work inline when it fits in a handful of tool calls, so spawning a subagent is over-delegation.'
max_turns: 10
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

In internal/delivery/api/fb/handlers/page_handler.go the default page list limit (defaultPagesLimit) is 50. Change it to 25.
