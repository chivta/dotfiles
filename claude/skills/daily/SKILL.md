---
name: daily
description: Draft my daily standup text in Ukrainian from Claude sessions, Jira and Google Calendar.
disable-model-invocation: true
---

# Daily

Draft my standup update: what I did on the previous working day and what I'll do today. The previous working day is yesterday, or Friday when today is Monday. Gather the three sources, then write the text.

`getWorkActivity` takes local-time ISO datetimes with the offset from `date +%z` (e.g. `2026-11-04T00:00:00+02:00`), because a bare `YYYY-MM-DD` is read as UTC and shifts the day by the offset. JQL rejects offsets and takes `"YYYY-MM-DD HH:mm"`, read in my Jira timezone.

## 1. Claude sessions

`python3 "<this skill's folder>/scripts/sessions.py"` prints every session from the previous working day 00:00 to now, grouped by day: project, branch, session titles, my prompts, commits (including those made by subagents), PR links and Claude's last reply. Sessions about my own tooling or personal projects (dotfiles, nvim, kitty, food tracking) don't go into the standup; questions that produced no work (a quick "how much does X cost") don't either.

## 2. Jira

Site `cloudId: "https://amomobile.atlassian.net"`, four calls:

- What I touched: `getWorkActivity` with `activity: "all"`, `types: "jira"`, `from` at the previous working day 00:00 and no `to`, `itemsPerSection: "50"`.
- What I moved, once per section so each move lands on its day: `searchJiraIssuesUsingJql` with `status CHANGED BY currentUser() DURING ("<prev day> 00:00", "<today> 00:00")`, then with `status CHANGED BY currentUser() AFTER startOfDay()`, fields `summary`, `status`. The result carries no target status, so the current status stands in for where I moved it.
- In progress: `searchJiraIssuesUsingJql` with `assignee = currentUser() AND statusCategory = "In Progress" ORDER BY updated DESC`, fields `summary`, `status`. The category covers In Progress, In Review and Ready for Testing.

## 3. Google Calendar

`python3 "<this skill's folder>/scripts/meetings.py"` prints my meetings from the previous working day through the end of today, grouped by day, without all-day events and events I declined. When it exits with "not authorized", write the text without meetings and say so in one line under the fence.

## Text

Ukrainian, one block with no blank lines, printed inside a ```text fence so it copies verbatim, and nothing else in the reply apart from the missing-source line above:

```text
Вчора:
- AT-10749 save as draft для нативних постів — фікси після рев'ю, перевів у Ready for Testing
- AT-10868 seo canonical — фікс і деплой на stage
- міти «Planning» о 12:00 і «Retro» о 16:00
Сьогодні:
- AT-10916 API changelog — продовжую
- на рев'ю: AT-10746 (відео в Google Drive), AT-10858 (cancel генерації)
- на тестуванні: AT-10859 (Partner with us), AT-10863 (оновлення FB-поста)
- міти «Daily» о 10:00 і «Grooming» о 15:00
```

On Monday the first header is «У п'ятницю:».

The previous-day section has one line per ticket or piece of work: the Jira key and a short human name of the task, then what happened in a few words (зробив, відкрив PR, пофіксив коментарі, перевів у <status>, задеплоїв). Sessions, commits, PRs and Jira activity about the same ticket merge into one line; the session's branch or title usually names the ticket. Work without a ticket gets a line named by what it was about. Meetings go on the last line of each section, by title and start time.

The today section starts with what today's sessions show I've already begun, then every in-progress task: each In Progress task on its own line, and the In Review and Ready for Testing tasks grouped into one line per status with a two-to-four-word name each. A task already covered by a line above isn't repeated.
