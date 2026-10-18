---
description: 'Signature split in pkg/rest with 40+ callers in a dozen packages. A refactor too wide for inline work; goes to a sonnet worker.'
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

rest.StructResponse and rest.CreateStructResponse in pkg/rest/response.go take an `extra any` argument that nearly every caller passes as nil. Change both to take only (w, s), add rest.StructResponseWithExtra and rest.CreateStructResponseWithExtra(w, s, extra) for the callers that really pass extras, and update every caller in the repo.
