---
name: daily
description: Draft my daily standup text in Ukrainian from Claude sessions, Jira, GitHub and Google Calendar.
disable-model-invocation: true
---

# Daily

Draft my standup update: what happened to my tasks on the previous working day and today. The previous working day is yesterday, or Friday when today is Monday. The weekend between them stays out of the standup, because the first section speaks for Friday alone: the scripts print only the previous working day and today, and Jira items dated Saturday or Sunday are dropped. Gather the four sources, then write the text.

`getWorkActivity` takes local-time ISO datetimes with the offset from `date +%z` (e.g. `2026-11-04T00:00:00+02:00`), because a bare `YYYY-MM-DD` is read as UTC and shifts the day by the offset. JQL rejects offsets and takes `"YYYY-MM-DD HH:mm"`, read in my Jira timezone.

## 1. Claude sessions

`python3 "<this skill's folder>/scripts/sessions.py"` prints every session on the previous working day and today, grouped by day: project, branch, session titles, my prompts, commits (including those made by subagents), PR links and Claude's last reply. Sessions about my own tooling or personal projects (dotfiles, nvim, kitty, food tracking) don't go into the standup; questions that produced no work (a quick "how much does X cost") don't either.

## 2. Jira

Site `cloudId: "https://amomobile.atlassian.net"`, four calls:

- What I touched: `getWorkActivity` with `activity: "all"`, `types: "jira"`, `from` at the previous working day 00:00 and no `to`, `itemsPerSection: "50"`.
- Status changes on my tasks, by anyone, once per section so each change lands on its day: `searchJiraIssuesUsingJql` with `(assignee = currentUser() OR status CHANGED BY currentUser() DURING (<window>)) AND status CHANGED DURING (<window>)`, where `<window>` is `"<prev day> 00:00", "<day after prev day> 00:00"` for the previous day; for today use `AFTER startOfDay()` in place of both `DURING (<window>)`. Fields `summary`, `status`. The result carries neither the target status nor who moved it, so the current status stands in for the target.
- In progress: `searchJiraIssuesUsingJql` with `assignee = currentUser() AND statusCategory = "In Progress" ORDER BY updated DESC`, fields `summary`, `status`. The category covers In Progress, In Review and Ready for Testing.

## 3. GitHub

`python3 "<this skill's folder>/scripts/prs.py"` prints, grouped by day, what happened in the window to `amomama` PRs I authored, reviewed or am asked to review: opened, reviews (approved, changes requested, commented), review requests, merges with the branch and who merged, closes. The PR title and branch carry the Jira key.

Anything said about a PR goes only as far as this output confirms. Sessions show what I worked on, and GitHub shows what actually happened. A review I ran locally in a session, with no review by `me` in the output, is «почав рев'ю», not «зарев'ював». When a session mentions a PR that isn't in the output, check it with `gh pr view <number> -R <owner/repo> --json state,latestReviews,reviewRequests`.

## 4. Google Calendar

`python3 "<this skill's folder>/scripts/meetings.py"` prints my meetings on the previous working day and today, grouped by day, without all-day events and events I declined. When it exits with "not authorized", write the text without meetings and say so in one line under the fence.

## Text

Ukrainian, one block with no blank lines, printed inside a ```text fence so it copies verbatim, and nothing else in the reply apart from the missing-source line above:

```text
Вчора:
- таски по розсилках — пофіксив конфлікти, змерджено в stage
- по превʼю статей і тегах отримав апрув
- відкрив PR по вебхуках партнерів, пофіксив коментарі з рев'ю, тепер у Ready for Testing
- мав міт з Олегом і грумінг
Сьогодні:
- розсилки задеплоєно
- продовжую таску про ліміти API
- на рев'ю превʼю статей і теги, на тестуванні пуші в Safari і фільтр по авторах
- буде міт по релізу
```

On Monday the first header is «У п'ятницю:».

Lines group work, not events. For each section, collect everything that happened to each ticket that day across all sources: work from sessions and commits, PR opened, reviews, fixes after review, merge into stage, Jira status changes, deploy; a session's or PR's branch or title usually names the ticket. Then join related things into one line: tickets of the same feature or area (one epic, one summary tag like `[Creative builder]`, one shared PR or branch), tickets with a similar update (merged, approved, in Ready for Testing, deployed), and work without a ticket that fed one (a design discussion that became the task). A small extra step of one ticket joins the shared update.

From Jira alone, a ticket makes it into the text in two ways: I created it in the window (the `created` tag from `getWorkActivity`), said as «завів таску про …», or it was created earlier and moved into In Progress in the window, said as «взяв з беклога таску про …». Other edits to tickets (description, fields, sprint, a ticket still in Backlog) aren't standup news and stay out.

Tasks are named short, by what unifies them, with no ticket keys: «таска по креейтів білдеру», «таска про атлас», «таски по метриках Facebook». The label comes from the summary tag, epic, branch or PR title, in words someone outside the code understands, with no code identifiers or field names. When those sources don't make the meaning clear, read the ticket with `getJiraIssue`.

Vary the wording the way a person talks: not every line starts with «таска»; mix «таска по …», «таски про …», «по …», «PR по …», and sometimes put the verb first. Updates are in dev slang with anglicisms. My own steps are in first person: пофіксив, відкрив PR, зарев'ював, отримав апрув. Merges into stage and deploys are done by others, and Jira doesn't say who moved a status, so those are stated as plain facts: змерджено в stage, задеплоєно, у Ready for Testing. Updates stay free of code identifiers and tool names: «згенерував порівняння API до і після PR», not «swagger diff через oasdiff».

Meetings go on the last line of each section and only say that they happened or will happen, with whom or about what: «мав міт з Богданом», «буде міт по RSOC». No times, and the daily standup itself isn't mentioned.

The today section starts with what already happened today, then every in-progress task not yet named in the today section: In Progress ones as continuing, In Review and Ready for Testing ones grouped by status.
