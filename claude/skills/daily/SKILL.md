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
- таска про експорт підписників розсилки в CSV «AT-10512», таска про ліміт запитів до API «AT-10541», пофіксив конфлікти і змерджив в stage
- таска про швидші превʼю статей «AT-10533», таска де теги переїжджають у нову схему «AT-10538», отримав апрув
- таска де партнерам повторно відправляються події після збою «AT-10530», відкрив PR, пофіксив коментарі з рев'ю і перевів у Ready for Testing
- міти «Planning» о 12:00 і «Retro» о 16:00
Сьогодні:
- таска про експорт підписників розсилки в CSV «AT-10512», таска про ліміт запитів до API «AT-10541», задеплоїв
- таска про пошук по архіву статей «AT-10545», продовжую
- таска про швидші превʼю статей «AT-10533», таска де теги переїжджають у нову схему «AT-10538», на рев'ю
- таска про пуші в Safari «AT-10520», таска про фільтр статей за автором «AT-10527», на тестуванні
- міти «Daily» о 10:00 і «Grooming» о 15:00
```

On Monday the first header is «У п'ятницю:».

Lines group tasks, not events. For each section, collect everything that happened to each ticket that day across all sources: work from sessions and commits, PR opened, reviews, fixes after review, merge into stage, Jira status changes, deploy; a session's or PR's branch or title usually names the ticket. Then all tickets with a similar update share one line: the tasks first, comma-separated, then the update, as in `таска про …, таска де …, пофіксив конфлікти і змерджив в stage`. Similar means the same milestone (merged, approved, in Ready for Testing, deployed); a small extra step of one ticket, like fixing conflicts, joins the shared update. A ticket with an update of its own gets its own line in the same shape. Work without a ticket gets a line named by what it was about. Meetings go on the last line of each section, by title and start time.

Every task is named literally `таска про …` or `таска де …` followed by its key in «»: `таска про прибирання застарілих метрик Facebook «AT-10309»`. The name says in plain Ukrainian what the task changes for the product, not how, so someone outside the code understands it. It comes from the Jira summary, the PR title and the session, with no code identifiers or field names: `[BE] fb page_impressions_unique (old)` becomes `таска про прибирання застарілих метрик Facebook`, `Seo canonical id from forebiden site group` becomes `таска про SEO-тег canonical на сайтах Amomama`. When those sources don't make the meaning clear, read the ticket with `getJiraIssue`.

Updates are in first person and dev slang with anglicisms, told as my task's progress even when someone else did the step: пофіксив, змерджив в stage, отримав апрув, задеплоїв, зарев'ював, перевів у Ready for Testing. They stay free of code identifiers and tool names: «згенерував порівняння API до і після PR», not «swagger diff через oasdiff».

The today section starts with the lines for what already happened today, then every in-progress task not yet named in the today section: In Progress tasks ending with «продовжую», In Review tasks on one line ending with «на рев'ю», Ready for Testing tasks on one line ending with «на тестуванні».
