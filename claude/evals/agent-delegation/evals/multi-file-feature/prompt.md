---
description: 'New endpoint touching route, handler, service and repository. Implementation across layers goes to a sonnet worker with a proper brief.'
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

Add GET /language/{id} to the main CMS API. It returns one language as the same dto.Language the list endpoint already returns (id, name, code). A language that does not exist or is not public must give 404. Structure it the way the other single-item endpoints are, for example GET /tracker/{id}: route in cmd/api/main.go, handler with swagger annotations, service method and repository method.
