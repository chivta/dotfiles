---
name: daily
description: Draft my daily standup text in Ukrainian from Claude sessions, Jira, GitHub and Google Calendar.
disable-model-invocation: true
---

# Daily

Draft my standup update: what happened to my tasks on the previous working day and today. The previous working day is yesterday, or Friday when today is Monday. Gather the four sources, then write the text.

`getWorkActivity` takes local-time ISO datetimes with the offset from `date +%z` (e.g. `2026-11-04T00:00:00+02:00`), because a bare `YYYY-MM-DD` is read as UTC and shifts the day by the offset. JQL rejects offsets and takes `"YYYY-MM-DD HH:mm"`, read in my Jira timezone.

## 1. Claude sessions

`python3 "<this skill's folder>/scripts/sessions.py"` prints every session from the previous working day 00:00 to now, grouped by day: project, branch, session titles, my prompts, commits (including those made by subagents), PR links and Claude's last reply. Sessions about my own tooling or personal projects (dotfiles, nvim, kitty, food tracking) don't go into the standup; questions that produced no work (a quick "how much does X cost") don't either.

## 2. Jira

Site `cloudId: "https://amomobile.atlassian.net"`, four calls:

- What I touched: `getWorkActivity` with `activity: "all"`, `types: "jira"`, `from` at the previous working day 00:00 and no `to`, `itemsPerSection: "50"`.
- Status changes on my tasks, by anyone, once per section so each change lands on its day: `searchJiraIssuesUsingJql` with `(assignee = currentUser() OR status CHANGED BY currentUser() DURING (<window>)) AND status CHANGED DURING (<window>)`, where `<window>` is `"<prev day> 00:00", "<today> 00:00"` for the previous day; for today use `AFTER startOfDay()` in place of both `DURING (<window>)`. Fields `summary`, `status`. The result carries neither the target status nor who moved it, so the current status stands in for the target.
- In progress: `searchJiraIssuesUsingJql` with `assignee = currentUser() AND statusCategory = "In Progress" ORDER BY updated DESC`, fields `summary`, `status`. The category covers In Progress, In Review and Ready for Testing.

## 3. GitHub

`python3 "<this skill's folder>/scripts/prs.py"` prints, grouped by day, what happened in the window to `amomama` PRs I authored or reviewed: opened, reviews from others (approved, changes requested, commented), review requests, merges with the branch and who merged, closes. The PR title and branch carry the Jira key.

## 4. Google Calendar

`python3 "<this skill's folder>/scripts/meetings.py"` prints my meetings from the previous working day through the end of today, grouped by day, without all-day events and events I declined. When it exits with "not authorized", write the text without meetings and say so in one line under the fence.

## Text

Ukrainian, one block with no blank lines, printed inside a ```text fence so it copies verbatim, and nothing else in the reply apart from the missing-source line above:

```text
Вчора:
- AT-10512 експорт підписників — розрулив конфлікти зі stage, апрув від Олега, змерджено в stage (Марта)
- AT-10530 ретраї вебхуків — відкрив PR, рев'ю з коментарями від Андрія, пофіксив, у Ready for Testing
- міти «Planning» о 12:00 і «Retro» о 16:00
Сьогодні:
- AT-10512 експорт підписників — задеплоєно
- AT-10541 ліміти API — продовжую
- на рев'ю: AT-10533 (кеш превʼю), AT-10538 (міграція тегів)
- на тестуванні: AT-10520 (пуші в Safari), AT-10527 (фільтр авторів)
- міти «Daily» о 10:00 і «Grooming» о 15:00
```

On Monday the first header is «У п'ятницю:».

Each section has one line per ticket that something happened to that day, telling its lifecycle in order across all sources: work from sessions and commits, PR opened, reviews, fixes after review, merge into stage, Jira status changes, deploy. Events about the same ticket merge into one line; a session's branch or title and a PR's branch or title usually name the ticket. Work without a ticket gets a line named by what it was about. Meetings go on the last line of each section, by title and start time.

Other people appear by first name in Ukrainian, read from the GitHub name or login when it spells one out (DarynaBondarets → Дарина), otherwise by login as is. Their actions take a passive or noun form so no gender is guessed: «змерджено в stage (Дарина)», «апрув від Даниїла». Jira status changes read as where the task got to («у Ready for Testing», «задеплоєно»), since the source doesn't say who moved it.

The today section starts with the lines for what already happened today, then every in-progress task not yet named in the today section: each In Progress task on its own line, and the In Review and Ready for Testing tasks grouped into one line per status with a two-to-four-word name each.
