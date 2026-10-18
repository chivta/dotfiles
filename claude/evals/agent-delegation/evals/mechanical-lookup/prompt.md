---
description: 'Inventory of about 160 routes spread over nine files. A large mechanical lookup belongs to a cheaper model (haiku or sonnet); the main opus session must not do it or hand it to opus.'
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

I need an inventory of every HTTP route the two servers expose: cmd/api and cmd/partner_api, including the routes registered by the modules under internal/delivery. For each route give the HTTP method, the path, the handler function it dispatches to, and the middleware that wraps it (router-level Use calls and the global wrappers in main.go). Reply with one markdown table per server.
