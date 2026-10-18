---
description: 'Two independent three-file changes in different packages (trackers, languages), no shared file. Parallel code-writing workers each need their own worktree.'
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

Two independent changes to the main CMS API, please do both. (1) GET /tracker/list should accept sortBy=name|code (and order=desc), as GET /menu/list already does for name: the sort key map goes in internal/trackers/dto/list.go, the ORDER BY in internal/trackers/repositories/tracker.go, and the swagger params in internal/trackers/handlers/tracker.go. (2) GET /language/list should accept an optional name query parameter that filters languages whose name contains it: field in internal/languages/dto/list.go, the WHERE in internal/languages/repositories/language.go (Count must apply it too), swagger params in internal/languages/handlers/language.go.
