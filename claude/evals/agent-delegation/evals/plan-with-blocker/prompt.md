---
description: 'Planning request with a product decision hidden in it (what a bulk request does when some pages fail). The skill says to settle blockers with the user before writing the plan, so no plan file may be written and the reply must ask.'
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

Write an implementation plan for a bulk-schedule feature: an editor picks one native post and several Facebook pages and gets the post scheduled on all of those pages with one request. Put the plan in a file under .claude/plans/.
