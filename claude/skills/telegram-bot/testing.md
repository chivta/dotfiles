
# Telegram bot testing

Bots break in the **wiring**, not in the handlers. A handler that formats a reply correctly is easy to unit test and rarely wrong. What goes wrong is everything around it: the bot is unreachable, answers the wrong chat, subscribes to the wrong update kinds, or exits before the command it just asked for can arrive. None of that is visible from a handler called in-process.

## Three tiers

| Tier | What it covers | What it costs | When |
|---|---|---|---|
| Unit | Handler logic, parsing, formatting | Milliseconds | Every save |
| **Fake server** | The wiring: reachability, routing, authorisation, ordering, side effects, error recovery | Seconds, no network | **Every push, in CI** |
| Manual | Telegram's own behaviour: parse modes, delete permissions, privacy mode, flood control | Minutes of a human's attention | When an assumption changes |

The middle tier is the one most bots are missing, and it is where this skill
spends its effort. For the third, see
[`reference/manual-checklist.md`](reference/manual-checklist.md).

## Real bugs the fake tier caught

None of these were visible to a unit test:

- **The bot said "send me `/settoken <secret>`" and then exited**, killing the
  listener that would receive it. Every individual piece was correct. The
  sequence was not.
- **Commands were only served after startup finished.** When startup was slow or
  stuck, the bot was silent precisely when its diagnostic commands mattered.
- **A privileged command answered from an unconfigured chat.** A public bot
  username was the only thing between a stranger and a credential-setting
  command.

## The one change your bot needs

The API base URL must be configurable. Wire it to an env var, `TELEGRAM_API_URL`,
empty in production. The same knob points at a self-hosted Bot API server or
Telegram's test environment.

| Framework | Knob |
|---|---|
| telebot (Go) | `tele.Settings{URL: apiURL}` |
| python-telegram-bot | `ApplicationBuilder().base_url(f"{api}/bot")` |
| aiogram | `TelegramAPIServer.from_base(api)` |
| telegraf (Node) | `new Telegraf(token, {telegram: {apiRoot: api}})` |
| grammY | `new Bot(token, {client: {apiRoot: api}})` |

```go
settings := tele.Settings{Token: token, Poller: poller}
if apiURL != "" {
	settings.URL = apiURL
}
```

## Wiring it in

Copy `reference/tgfake/` to `internal/tgfake/` and
`reference/example_offline_test.go` to `test/offline/`. Adjust the module path,
the environment your bot reads, and the assertions. Nothing beyond the standard
library is required, and the token can be any string, because the fake never
checks it. Commit the suite; it needs no build tag and no exclusion from CI.

The test drives the bot with `SendCommand`, `SendText`, `EditText`,
`ClickButton`, `ChatMemberChange` and `InlineQuery`, then asserts with
`WaitForMessage`, `WaitForCall`, `WaitForDelete`, `IndexOf` and
`ExpectNoMessageTo`.

**Webhook bots need no change to the harness.** When the bot calls `setWebhook`,
the fake records the URL and POSTs updates there instead of serving `getUpdates`.
Point the bot's advertised webhook URL at its own local listener.

## What to assert

Aim at the seams, not the logic.

- A command is **routed and answered**, with the reply text a user would see.
- Commands from **another chat** are ignored. `ExpectNoMessageTo`, scoped.
- A message carrying a **credential is deleted**, by message id, and deleted
  before the confirmation rather than after.
- The bot is **reachable during startup**, not only after it succeeds. Start it
  with a dead upstream so it stalls, then send a command.
- **Buttons are answered.** Skipping `answerCallbackQuery` leaves the user's
  client spinning until it times out.
- **Side effects landed.** Read the bot's own store. "Saved" in a message and a
  row in a table are different claims.
- The bot **survives the API failing** under it, including a 403 after a user
  blocks it.

## What only a fake can do

Provoke failures on demand. Real Telegram will not return a 400 or a 429 because
your test asked, so error-handling paths are otherwise untested.

```go
fake.FailNext("sendMessage", 400, "Bad Request: message is too long")
```

Then assert the bot is still answering afterwards. A bot that dies on its first
failed send is a real and common bug.

## Traps

These all cost real debugging time. They are not hypothetical.

**Scope negative assertions by chat.** A bot messages its own chat for unrelated
reasons: startup notices, error alerts. An unscoped "did it send anything?"
check reads those as "the bot answered a chat it should not have", which is a
false report of a security hole. Use `ExpectNoMessageTo(chatID, window)`. This
produced a failing test on the very first run.

**Commands need their entity.** A message whose text starts with `/` is not a
command to a bot framework unless the `bot_command` entity is attached.
`SendCommand` attaches it and `SendText` does not, which is the difference
between the two. Without it the handler never fires and the test times out with
no clue why.

**Subscribe to the update kinds you handle.** `allowed_updates` defaults to
everything except `chat_member`, `message_reaction` and
`message_reaction_count`. A bot that handles `chat_member` perfectly and never
subscribed receives nothing, and the symptom is silence rather than an error.
The fake filters the same way, so the test reproduces it.

**Assert on the message id, not the method.** A bot that deletes its own prompt
instead of the user's credential passes "was anything deleted?" while leaving
the secret in the chat. `WaitForDelete(chatID, messageID, timeout)`.

**Do not build into `t.TempDir()` and cache it.** That directory is removed when
the test that created it ends, so a binary cached across tests vanishes
mid-suite. Build once in `TestMain` into a directory you clean up yourself.

**Let `getUpdates` block briefly.** Returning instantly turns the bot's polling
loop into a busy spin that drowns the test in requests. A couple of seconds is
enough, and well under the caller's own timeout so shutdown stays responsive.

**Wait on conditions, never on the clock.** `time.Sleep` as synchronisation is
how a suite becomes flaky on a loaded CI machine. Every helper here polls to a
deadline instead. Give each test its own fake and its own store so tests stay
independent.

**Print the bot's own log when an assertion fails.** It separates "the bot tried
and failed" from "the bot never tried", which are identical from the API side.
This is what prevents "fixing" code that was already correct, and it is what
identified the unscoped-assertion trap above in seconds.

**Return the offending value, not an error, from negative assertions.** A test
must be able to tell "the bot did something it should not have" apart from a
harness problem. Conflating them turns a hiccup into a false alarm.

## What the fake cannot tell you

It models the API, not Telegram. It will accept a delete Telegram would refuse,
a parse mode Telegram would reject, and a 5000-character message Telegram would
truncate. It also does not record `getUpdates`, so polling cadence is not
assertable. Treat those assumptions as untested and run
[`reference/manual-checklist.md`](reference/manual-checklist.md) against a real
bot when they change.
