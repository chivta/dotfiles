package bot

import (
	"errors"
	"fmt"
	"strings"

	"github.com/example/mybot/internal/domain"
)

// Every user-facing string lives here. Nothing in the other layers formats text
// for a human: they pass states and domain errors, and this file names them.
// Keeping it in one file is what makes the bot translatable later, and what
// stops HTML-escaping bugs from spreading through business logic.
const (
	textStart = "👋 Send me a message and I'll get to work.\n\n" +
		"For example:\n<code>something to look up</code>"
	textEmptyQuery = "Send me something to work with."
	textQueued     = "⏳ Queued…"
	textWorking    = "⚙️ Working…"
	textSending    = "📤 Sending…"

	// textCaption is the caption under a delivered result.
	textCaption = "<b>%s</b>"
)

// errorText maps every domain error onto the one sentence the user gets. An
// error missing from this map is a bug on our side, not theirs — which is why
// the fallback apologises rather than leaking the error.
var errorText = map[error]string{
	domain.ErrNotFound:     "🤷 Couldn't find anything for that.",
	domain.ErrInvalidInput: "🤔 I didn't understand that. Try rephrasing.",
	domain.ErrRateLimited:  "🐢 You've hit your limit. Try again in a little while.",
	domain.ErrQueueFull:    "🚦 I'm at capacity right now. Try again in a minute.",
	domain.ErrUnauthorized: "🔒 This bot is private.",
	domain.ErrTimeout:      "⏱ That took too long and I gave up.",
}

const textUnexpected = "💥 Something went wrong on my side. Try again."

// describe names an error for the user, falling back to the generic apology.
func describe(err error) string {
	for sentinel, text := range errorText {
		if errors.Is(err, sentinel) {
			return text
		}
	}

	return textUnexpected
}

// stateText names a job state for the user.
func stateText(state domain.State) string {
	switch state {
	case domain.StateWorking:
		return textWorking
	case domain.StateSending:
		return textSending
	default:
		return textQueued
	}
}

func caption(res domain.Result) string {
	return fmt.Sprintf(textCaption, escape(res.Title))
}

// escape makes a value safe for tele.ModeHTML. Every interpolated value goes
// through it: one raw "<" in a title makes Telegram reject the whole message.
func escape(s string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;").Replace(s)
}
