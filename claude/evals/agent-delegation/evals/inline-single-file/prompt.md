---
description: 'Two small edits inside one function of one file. One pass, one file: inline per the skill, so spawning a subagent is over-delegation.'
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

In RetryPublish in internal/modules/fb/schedule/services/schedule_service.go, the loop that looks for a free minute drops the cause of a repository failure (it returns "fail Schedules in ScheduleRepository" with no wrapped error), and the final "fail, time not found" error does not say which schedule it was or how many attempts were made. Wrap the repository error with %w like the other call sites in that file, and include the schedule ID and retryAttemptLimit in the final error.
