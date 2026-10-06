// Template for a fake-server suite. Copy into test/offline/, adjust the module
// path, the environment your bot reads, and the assertions.
//
//	go test ./test/offline/
//
// The fixture bot here has two commands, /ping and /settoken <secret>, which
// between them exercise every property worth covering: routing, chat gating,
// credential handling, ordering, persistence and error recovery. Map them onto
// your own commands rather than copying the names.
//
// Package offline drives the bot against a fake Bot API server. No network, no
// credentials, no Telegram: it runs anywhere, including CI, and finishes in
// seconds. The bot itself is untouched, a real process with a real HTTP client
// and a real polling loop, so the wiring these tests cover is the real wiring.
package offline

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"example.com/yourmodule/internal/tgfake" // adjust to your module path
)

const (
	chatID = int64(4242)
	// replyWait is generous relative to a local round trip, so a slow CI
	// machine does not produce a flake.
	replyWait = 30 * time.Second
	// silenceWait is how long a command that must be ignored is watched.
	silenceWait = 3 * time.Second
)

// TestAnswersDuringStartup runs first for a reason. A bot whose diagnostic
// commands only work once initialisation succeeds is silent exactly when they
// matter. The fixture is started with a broken upstream so it stalls before it
// is ready, and /ping must still answer.
func TestAnswersDuringStartup(t *testing.T) {
	fake, _ := startBot(t)

	fake.SendCommand(chatID, "/ping")

	if _, err := fake.WaitForMessage("pong", replyWait); err != nil {
		t.Fatalf("ping went unanswered during startup: %v", err)
	}
}

// TestIgnoresOtherChats is the one that matters most. A bot's username is
// public, so chat gating is often all that stands between a stranger and a
// credential-setting command.
func TestIgnoresOtherChats(t *testing.T) {
	fake, statePath := startBot(t)

	foreign := chatID + 1
	fake.SendCommand(foreign, "/settoken from-a-stranger")

	// Scoped to the foreign chat: the bot legitimately messages its own chat
	// about unrelated things, and counting those would be a false alarm.
	if reply := fake.ExpectNoMessageTo(foreign, silenceWait); reply != "" {
		t.Errorf("bot answered a chat it is not configured for: %q", reply)
	}
	if stored := storedToken(t, statePath); stored != "" {
		t.Errorf("a foreign chat set the token to %q", stored)
	}
}

func TestSetToken(t *testing.T) {
	t.Run("without a payload it explains itself", func(t *testing.T) {
		fake, _ := startBot(t)

		fake.SendCommand(chatID, "/settoken")

		if _, err := fake.WaitForMessage("Send the token with the command", replyWait); err != nil {
			t.Fatalf("usage reply: %v", err)
		}
	})

	t.Run("a malformed value is rejected and not stored", func(t *testing.T) {
		fake, statePath := startBot(t)

		fake.SendCommand(chatID, "/settoken nope")

		if _, err := fake.WaitForMessage("does not look like a token", replyWait); err != nil {
			t.Fatalf("rejection reply: %v", err)
		}
		// A typo must not reach the store.
		if stored := storedToken(t, statePath); stored != "" {
			t.Errorf("stored %q, want nothing persisted", stored)
		}
	})

	t.Run("a valid value is applied and persisted", func(t *testing.T) {
		fake, statePath := startBot(t)

		token := fmt.Sprintf("tok_%d", time.Now().UnixNano())
		fake.SendCommand(chatID, "/settoken "+token)

		if _, err := fake.WaitForMessage("Token saved", replyWait); err != nil {
			t.Fatalf("confirmation: %v", err)
		}
		// The reply claiming success and the value being on disk are different
		// claims. Read the bot's own store and check the second one.
		if stored := waitForToken(t, statePath, replyWait); stored != token {
			t.Errorf("stored %q, want the token that was sent", stored)
		}
	})

	t.Run("the message carrying the token is deleted before the reply", func(t *testing.T) {
		fake, _ := startBot(t)

		sent := fake.SendCommand(chatID, "/settoken tok_deleteme")

		// The exact message id, not "was anything deleted": a bot that removes
		// its own prompt instead leaves the secret sitting in the chat.
		if err := fake.WaitForDelete(chatID, sent, replyWait); err != nil {
			t.Fatalf("the credential message survived: %v", err)
		}

		// Ordering is its own property. Confirming first and deleting later
		// leaves a window, and a crash in between makes it permanent.
		deleted := fake.IndexOf("deleteMessage", "", "")
		confirmed := fake.IndexOf("sendMessage", "text", "Token saved")
		if confirmed >= 0 && deleted > confirmed {
			t.Errorf("confirmed at %d before deleting at %d", confirmed, deleted)
		}
	})
}

// TestButtonsAreAnswered covers the inline keyboard path. Skipping
// answerCallbackQuery leaves the user's client spinning until it times out,
// which no unit test notices and every user does.
func TestButtonsAreAnswered(t *testing.T) {
	fake, _ := startBot(t)

	prompt, err := fake.WaitForCall("sendMessage", "text", "Choose", replyWait)
	if err != nil {
		t.Skip("fixture sent no keyboard; adapt this to a command of yours that does")
	}

	fake.ClickButton(chatID, prompt.Int("message_id"), "confirm")

	if _, err := fake.WaitForCall("answerCallbackQuery", "", "", replyWait); err != nil {
		t.Fatalf("the button was never answered: %v", err)
	}
}

// TestSurvivesBeingBlocked checks the bot keeps running after a user blocks it.
// Telegram then rejects every send to that chat, and a bot that treats the
// error as fatal takes itself down because one person tapped Block.
func TestSurvivesBeingBlocked(t *testing.T) {
	fake, bot := startBot(t)

	fake.ChatMemberChange(chatID, "member", "kicked")
	fake.FailNext("sendMessage", 403, "Forbidden: bot was blocked by the user")
	fake.SendCommand(chatID, "/ping")

	fake.SendCommand(chatID, "/ping")
	if _, err := fake.WaitForMessage("pong", replyWait); err != nil {
		t.Fatalf("bot stopped answering after being blocked: %v\n%s", err, bot.Logs())
	}
}

// TestSurvivesTelegramErrors checks the bot keeps serving after the API fails
// under it. Provoking this is the thing a fake can do that the real API cannot.
func TestSurvivesTelegramErrors(t *testing.T) {
	fake, _ := startBot(t)

	fake.FailNext("sendMessage", 400, "Bad Request: message is too long")
	fake.SendCommand(chatID, "/ping")

	// The failure is swallowed; the next command must still be answered.
	fake.SendCommand(chatID, "/ping")

	if _, err := fake.WaitForMessage("pong", replyWait); err != nil {
		t.Fatalf("bot stopped answering after a send failure: %v", err)
	}
}

// startBot runs the bot with a deliberately unusable upstream, so it stalls
// before it is ready. That is the state where commands matter most. It returns
// the fake and the path to the bot's own store.
func startBot(t *testing.T) (*tgfake.Server, string) {
	t.Helper()

	fake := tgfake.New()
	t.Cleanup(fake.Close)

	statePath := filepath.Join(t.TempDir(), "state.db")

	bot, err := tgfake.StartProcess(buildBinary(t), map[string]string{
		"BOT_TOKEN": "123456:FAKE",
		"CHAT_ID":   fmt.Sprintf("%d", chatID),
		"DB_PATH":   statePath,
		// The bot must reach the fake instead of Telegram.
		"TELEGRAM_API_URL": fake.URL(),
		"HTTP_ADDR":        "127.0.0.1:0",
		"LOG_LEVEL":        "info",
		// Whatever your bot talks to besides Telegram, point it somewhere dead
		// so startup stalls and the "answers while starting" property is real.
		"UPSTREAM_URL": "http://127.0.0.1:1",
	})
	if err != nil {
		t.Fatalf("start bot: %v", err)
	}
	t.Cleanup(bot.Stop)

	// Wait for a line the bot logs once its listener is up, not for a line
	// meaning startup finished. Those are different moments and the gap between
	// them is what these tests are about.
	if err := bot.WaitForLog("telegram command listener started", replyWait); err != nil {
		t.Fatalf("startup: %v", err)
	}

	// The bot's own log separates "tried and failed" from "never tried", which
	// the API side alone cannot.
	t.Cleanup(func() {
		if t.Failed() {
			t.Logf("--- bot log ---\n%s", bot.Logs())
		}
	})

	return fake, statePath
}

// binaryPath is built once for the whole package.
//
// It deliberately avoids t.TempDir(): that directory is removed when the test
// that created it ends, which would delete the binary out from under every
// later test.
var binaryPath string

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "yourbot-offline")
	if err != nil {
		fmt.Fprintf(os.Stderr, "temp dir: %v\n", err)
		os.Exit(1)
	}

	binaryPath = filepath.Join(dir, "yourbot")

	build := exec.Command("go", "build", "-o", binaryPath, "../../cmd/yourbot")
	out, err := build.CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "build: %v\n%s", err, out)
		os.RemoveAll(dir)
		os.Exit(1)
	}

	code := m.Run()
	os.RemoveAll(dir)
	os.Exit(code)
}

func buildBinary(t *testing.T) string {
	t.Helper()

	return binaryPath
}

// storedToken reads the value straight out of the bot's store. Replace the body
// with whatever your bot persists to: a SQL query, a bucket read, a file.
// Reading through the bot's own API would only tell you what the bot believes.
func storedToken(t *testing.T, statePath string) string {
	t.Helper()

	raw, err := os.ReadFile(statePath)
	if err != nil {
		if os.IsNotExist(err) {
			return ""
		}
		t.Fatalf("read bot state: %v", err)
	}

	return strings.TrimSpace(string(raw))
}

// waitForToken allows for the reply arriving before the write lands.
func waitForToken(t *testing.T, statePath string, timeout time.Duration) string {
	t.Helper()

	deadline := time.Now().Add(timeout)
	for {
		value := storedToken(t, statePath)
		if value != "" || time.Now().After(deadline) {
			return value
		}
		time.Sleep(50 * time.Millisecond)
	}
}
