# The manual pass

Run this against a real bot when any assumption below changes, not on every
push. It exists because the fake models the Bot API, not Telegram: it will
happily accept a delete Telegram would refuse and a parse mode Telegram would
reject.

## Where to run it

Use a throwaway bot from @BotFather, never the production token. Three options,
cheapest first.

**A second bot in the main environment.** A new token, a private chat with
yourself, and a test group. Covers everything below. This is the default.

**Telegram's test environment.** A separate set of servers with looser
restrictions, useful when you need HTTP links without TLS for Web Apps or Web
Login. It shares nothing with the main environment, so you need a new account
and a new bot registered with @BotFather from inside it.

- Endpoint: `https://api.telegram.org/bot<token>/test/METHOD_NAME`
- iOS: tap the Settings icon 10 times, Accounts, Login to another account, Test
- Desktop: Settings, then Shift+Alt+right-click 'Add Account', pick 'Test Server'
- macOS: click Settings 10 times for the Debug Menu, Cmd+click 'Add Account'

**A self-hosted Bot API server.** `telegram-bot-api` run locally raises the file
size limits and removes the API server as a shared bottleneck. It still talks to
Telegram, so it is a transport change, not an offline mode. Point
`TELEGRAM_API_URL` at it, the same knob the fake uses.

## The checklist

**Formatting actually parses.** `parse_mode: MarkdownV2` rejects unescaped
`_ * [ ] ( ) ~ > # + - = | { } . !` anywhere in the text, including inside
values you interpolate. HTML mode accepts only a fixed tag list. The failure is
a 400 at send time, so any message built from user data or upstream data needs
one real send with a hostile value in it.

**Long messages.** Text caps at 4096 characters after entity parsing, captions
at 1024. A bot that formats a list has no upper bound on it until someone's list
is long. Send one that exceeds the cap and confirm the bot splits rather than
losing the message.

**Deletion is permitted.** The rules, verbatim from the API docs:

- A message can only be deleted if it was sent less than 48 hours ago
- Bots can delete outgoing messages in private chats, groups and supergroups
- Bots can delete incoming messages in private chats
- If the bot is an administrator of a group, it can delete any message there
- In a supergroup or channel it needs `can_delete_messages`

Deleting a user's credential message works in a private chat and fails in a
group unless the bot is an admin. If your bot accepts secrets in groups, verify
this by hand, because the fake accepts the call either way.

**Privacy mode.** Enabled by default, and in a group it means the bot only sees
commands addressed to it (`/command@yourbot`), bare commands when it sent the
last message, replies to its own messages, and service messages. Turning it off
in @BotFather **requires re-adding the bot to the group** before the change
takes effect, which is the step people miss when a group bot mysteriously sees
nothing.

**Keyboards render.** Inline keyboard layout, button labels, and what happens on
tap. The fake confirms `answerCallbackQuery` was called; only a real client
shows you whether the spinner clears and whether the message edits in place.

**Files.** Upload and download limits, and that whatever you send arrives as the
type you meant: a document rather than a compressed photo, a video rather than a
file.

**Flood control.** Telegram returns 429 with `retry_after` in
`ResponseParameters`. Confirm the bot waits that long rather than retrying
immediately or dropping the message. Provoke it with a burst; the exact
thresholds are undocumented and change.

**Group and channel behaviour.** Chat ids are negative, supergroup migration
changes them, and permissions differ from private chats. Every assumption a bot
makes about "the chat" deserves one run in each place it will actually be used.

**Restart with real state.** Stop the bot mid-conversation and start it again.
Anything held only in memory is gone, and the user is left in a state the bot no
longer recognises.
