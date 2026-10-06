package bot

import (
	"context"
	"strings"
	"time"

	"github.com/rs/zerolog/log"
	tele "gopkg.in/telebot.v4"

	"github.com/example/mybot/internal/domain"
	"github.com/example/mybot/internal/metrics"
)

const (
	// pollerTimeout is how long a long-poll request waits for an update.
	pollerTimeout = 10 * time.Second
	// sendRate and sendBurst keep every outbound call, across all chats and
	// workers, inside Telegram's global 30-per-second ceiling.
	sendRate  = 25
	sendBurst = 5
)

// submitter is the work pipeline seen from the delivery layer. Declaring it
// here, in the consumer, is what keeps the dependency pointing one way.
type submitter interface {
	Submit(job domain.Job) error
}

// Bot is the Telegram delivery layer. It accepts requests, hands them to the
// pipeline and renders whatever comes back; it holds no business logic.
type Bot struct {
	bot     *tele.Bot
	jobs    submitter
	allowed map[int64]bool
	sends   *sendLimiter
}

// New builds the bot. An empty allowedUsers means anyone may use it.
func New(token string, allowedUsers []int64) (*Bot, error) {
	inner, err := tele.NewBot(tele.Settings{
		Token:  token,
		Poller: &tele.LongPoller{Timeout: pollerTimeout},
		OnError: func(err error, c tele.Context) {
			log.Error().Err(err).Msg("telegram handler failed")
		},
	})
	if err != nil {
		return nil, err
	}

	return &Bot{
		bot:     inner,
		allowed: allowList(allowedUsers),
		sends:   newSendLimiter(sendRate, sendBurst),
	}, nil
}

// Run registers the handlers and serves updates until ctx is cancelled.
//
// The submitter arrives here rather than in New because the bot and the
// pipeline reference each other; handing it over at Run means neither has to be
// constructed half-finished.
func (b *Bot) Run(ctx context.Context, jobs submitter) error {
	b.jobs = jobs

	b.bot.Handle("/start", b.handleStart)
	b.bot.Handle("/help", b.handleStart)
	b.bot.Handle(tele.OnText, b.handleRequest)

	err := b.bot.SetCommands([]tele.Command{
		{Text: "start", Description: "what this bot does"},
		{Text: "help", Description: "what this bot does"},
	})
	if err != nil {
		// Not fatal: the bot works fine, the command menu is just not published.
		log.Warn().Err(err).Msg("failed to publish bot commands")
	}

	// telebot's Start blocks and has no context-aware variant, so cancellation
	// is bridged onto Stop.
	go func() {
		<-ctx.Done()
		b.bot.Stop()
	}()

	log.Info().Str("username", b.bot.Me.Username).Msg("telegram bot listening")
	b.bot.Start()
	log.Info().Msg("telegram bot stopped")

	return nil
}

func (b *Bot) handleStart(c tele.Context) error {
	if !b.authorized(c) {
		return c.Send(describe(domain.ErrUnauthorized))
	}

	return c.Send(textStart, tele.ModeHTML, tele.NoPreview)
}

// handleRequest turns a message into a queued job. It answers immediately with
// a placeholder the workers then edit, so the handler never waits on slow work —
// a blocked handler stalls the update loop for every other user too.
func (b *Bot) handleRequest(c tele.Context) error {
	if !b.authorized(c) {
		return c.Send(describe(domain.ErrUnauthorized))
	}

	query := strings.TrimSpace(c.Text())
	if query == "" {
		return c.Send(textEmptyQuery)
	}

	status, err := c.Bot().Send(c.Chat(), textQueued)
	if err != nil {
		return err
	}

	job := domain.Job{
		UserID:          c.Sender().ID,
		ChatID:          c.Chat().ID,
		StatusMessageID: status.ID,
		Query:           query,
		RequestedAt:     time.Now(),
	}

	err = b.jobs.Submit(job)
	if err != nil {
		metrics.IncRejected()
		log.Info().Err(err).Int64("user_id", job.UserID).Msg("request rejected")
		_, editErr := c.Bot().Edit(status, describe(err))

		return editErr
	}

	metrics.IncRequest()
	log.Info().Int64("user_id", job.UserID).Str("query", query).Msg("request queued")

	return nil
}

// authorized reports whether the sender of an update may use the bot.
func (b *Bot) authorized(c tele.Context) bool {
	sender := c.Sender()
	if sender == nil {
		// An update with no identifiable sender is only let through when the
		// bot is public anyway.
		return len(b.allowed) == 0
	}

	return b.allows(sender.ID)
}

// allows reports whether a user ID is on the allow list. An empty list means no
// list was configured, which makes the bot public — stated explicitly here
// because "no users configured" silently meaning "everyone" is otherwise an
// unpleasant surprise.
func (b *Bot) allows(id int64) bool {
	if len(b.allowed) == 0 {
		return true
	}

	return b.allowed[id]
}

// allowList indexes the configured user IDs for lookup.
func allowList(ids []int64) map[int64]bool {
	allowed := make(map[int64]bool, len(ids))
	for _, id := range ids {
		allowed[id] = true
	}

	return allowed
}
