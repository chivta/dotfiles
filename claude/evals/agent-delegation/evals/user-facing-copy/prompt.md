---
description: 'Reword an error editors see, across three files in three packages. The skill sends user-visible copy to sonnet or above, never haiku.'
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, Agent]
append_system_prompt: 'In the main conversation with the user, you are the orchestrator: your context is reserved for planning, coordination and review, so implementation goes to subagents, and you read the `agent-delegation` skill before delegating. As a subagent working from a brief, you are the worker: do the work in the brief yourself.'
---

Editors who retry a native post schedule that is not in the not-posted status (POST /fb/schedule-native-post/{id}/retry) get a 422 whose whole body is "current status: <status>". Reword it so an editor knows what to do, along the lines of: Only schedules in the not posted status can be retried; this one is currently <status>. Use the same wording in the Error() text of RetryPublishScheduleNativePostIsNotNotPublishedError and RetryPublishScheduleIsNotNotPublishedError in pkg/contracts/fb, so logs and API agree, and keep the status name coming from Status.String().
