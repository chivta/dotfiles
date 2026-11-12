---
name: telegram-bot
description: Preferred stack, defaults, and testing approach for Telegram bots in Go. Use when the user asks to create a Telegram bot, add a command or feature to one, set up its storage or deployment, or write, run and debug bot tests — including bare requests like "make me a telegram bot that..." that never mention Go, telebot or SQLite. Covers the bot-specific choices that general Go conventions get wrong, a runnable template in assets/template/, and a fake Bot API harness in reference/.
---

# Telegram bots

Go style and Dockerfile stages are already covered by the `golang-code-style`
skill and CLAUDE.md.
This file only covers what those get *wrong* for a bot, plus the telebot traps
that do not show up until the bot is under load.

## Stack

- **telebot v4** (`gopkg.in/telebot.v4`), long polling.
- **SQLite, not Postgres.** Postgres is right for a service, wrong for a bot. A bot's state
  is small and single-writer, and a personal bot is not worth a database server
  next to it. Use `modernc.org/sqlite` — pure Go, so `CGO_ENABLED=0` still
  yields a static binary — with `_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)`.
  Reach for Postgres only when something genuinely needs concurrent writers.
- **Allow list by Telegram user ID**, from `ALLOWED_USERS` (comma-separated).
  Empty means public — say so explicitly, since "nobody configured" silently
  meaning "everybody" is a bad surprise. For a single-chat bot, pin `CHAT_ID`
  instead and ignore updates from any other chat: the bot's username is public,
  so anyone can message it.

## Scaffolding

```bash
cp -r <skill-path>/assets/template <target-dir>
cd <target-dir>
mv cmd/mybot cmd/<botname>
mv go.mod.tmpl go.mod
grep -rl 'mybot\|github.com/example/mybot' . | xargs sed -i \
  -e 's|github.com/example/mybot|<module-path>|g' -e 's|mybot|<botname>|g'
go mod tidy && go build ./...
```

Then set the `image:` line in `k8s/bot/deployment.yaml` and the two age keys in
`.sops.yaml` by hand. The template is the request/response shape; for a
ticker-driven watcher, drop `internal/worker/` and add the poll loop.

## The telebot traps

These are the ones that get missed. Everything else about telebot is
discoverable from its docs.

**Never block a handler.** telebot dispatches updates through a shared loop, so
a handler that waits on slow work stalls it for every other user. Answer
immediately with a placeholder message, queue the job, return; the worker edits
that placeholder via `tele.StoredMessage{MessageID: strconv.Itoa(id), ChatID: id}`.

**Rate limit every outbound call through one shared limiter.** Telegram's
ceiling is ~30 calls/sec across the whole bot, and workers editing progress
messages blow through it. One `golang.org/x/time/rate` limiter at 25/sec burst 5,
shared by every send, edit and delete. This only bites under load, which is why
it goes in from the start.

**Escape interpolated values under `tele.ModeHTML`.** One raw `<` makes Telegram
reject the whole message. Prefer `ModeHTML` over Markdown; its escaping rules
are far less error-prone.

**File IDs are a free cache.** Telegram keeps every file you upload. Store the
returned `FileID` and re-send by ID instead of redoing the work.

## Deployment

Per CLAUDE.md, with one bot-specific constraint: SQLite is a single file on a
`ReadWriteOnce` volume, so the deployment is **one replica with
`strategy: Recreate`**. A rolling update deadlocks on the mount, and two
replicas would put two writers on one file. Long polling also permits only one
consumer per token.

## Testing

Bots break in the wiring, not in the handlers. The bug is that the bot is
unreachable, answers the wrong chat, subscribes to the wrong update kinds, or
exits before the command it just asked for can arrive. A handler called
in-process shows none of that.

So the bot needs one thing from the start, and it is easiest to put in while
scaffolding: **the API base URL must be configurable**, from `TELEGRAM_API_URL`,
empty in production.

```go
settings := tele.Settings{Token: token, Poller: poller}
if apiURL != "" {
	settings.URL = apiURL
}
```

That one knob lets the whole bot run as a real process against a fake Bot API
server, with no network and nothing to configure, so the suite runs in CI on
every push. The harness is in `reference/tgfake/`, a worked example in
`reference/example_offline_test.go`, and the human pass for what a fake cannot
model in `reference/manual-checklist.md`.

Read `testing.md` next to this file before writing bot tests. It covers what to
assert, how to provoke API failures on demand, and the traps that cost real
debugging time.

## Related

`golang-code-style` for Go style.
