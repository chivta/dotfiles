package bot

import (
	"context"
	"fmt"
	"strconv"

	"github.com/rs/zerolog/log"
	tele "gopkg.in/telebot.v4"

	"github.com/example/mybot/internal/domain"
)

// Progress reports how far along a job is by rewriting its status message.
func (b *Bot) Progress(ctx context.Context, job domain.Job, state domain.State) error {
	return b.editStatus(ctx, job, stateText(state))
}

// Deliver sends a finished result and returns the Telegram file ID it was
// stored under, which is what lets the next identical request skip the work.
func (b *Bot) Deliver(ctx context.Context, job domain.Job, res domain.Result) (string, error) {
	doc := &tele.Document{
		File:     tele.FromDisk(res.Path),
		FileName: res.Title,
		Caption:  caption(res),
	}

	msg, err := b.send(ctx, job, doc)
	if err != nil {
		return "", fmt.Errorf("send result: %w", err)
	}

	b.clearStatus(ctx, job)

	if msg.Document == nil {
		// Telegram accepted the upload but classified it as something else, so
		// there is no ID worth caching.
		log.Warn().Str("key", res.Key).Msg("delivered file was not stored as a document")
		return "", nil
	}

	return msg.Document.FileID, nil
}

// DeliverCached re-sends a result by the file ID Telegram already holds, which
// costs one API call and no work at all.
func (b *Bot) DeliverCached(ctx context.Context, job domain.Job, res domain.Result) error {
	doc := &tele.Document{
		File:     tele.File{FileID: res.FileID},
		FileName: res.Title,
		Caption:  caption(res),
	}

	_, err := b.send(ctx, job, doc)
	if err != nil {
		return fmt.Errorf("send cached result: %w", err)
	}

	b.clearStatus(ctx, job)

	return nil
}

// Fail replaces the status message with the reason the request went nowhere.
func (b *Bot) Fail(ctx context.Context, job domain.Job, cause error) {
	err := b.editStatus(ctx, job, describe(cause))
	if err != nil {
		log.Error().Err(err).Int64("chat_id", job.ChatID).Msg("failed to report job failure")
	}
}

func (b *Bot) send(ctx context.Context, job domain.Job, what interface{}) (*tele.Message, error) {
	err := b.sends.wait(ctx)
	if err != nil {
		return nil, err
	}

	return b.bot.Send(&tele.Chat{ID: job.ChatID}, what, tele.ModeHTML)
}

// editStatus rewrites the placeholder message the handler left behind. A failed
// edit is not worth failing a job over — the result still arrives.
func (b *Bot) editStatus(ctx context.Context, job domain.Job, text string) error {
	err := b.sends.wait(ctx)
	if err != nil {
		return err
	}

	_, err = b.bot.Edit(statusMessage(job), text, tele.ModeHTML, tele.NoPreview)
	if err != nil {
		log.Debug().Err(err).Int64("chat_id", job.ChatID).Msg("failed to edit status message")
	}

	return nil
}

// clearStatus removes the placeholder once the result has been delivered.
func (b *Bot) clearStatus(ctx context.Context, job domain.Job) {
	err := b.sends.wait(ctx)
	if err != nil {
		return
	}

	err = b.bot.Delete(statusMessage(job))
	if err != nil {
		log.Debug().Err(err).Int64("chat_id", job.ChatID).Msg("failed to delete status message")
	}
}

// statusMessage addresses the placeholder without having to hold the original
// *tele.Message, which the worker never sees.
func statusMessage(job domain.Job) tele.StoredMessage {
	return tele.StoredMessage{
		MessageID: strconv.Itoa(job.StatusMessageID),
		ChatID:    job.ChatID,
	}
}
