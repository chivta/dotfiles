package worker

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/rs/zerolog/log"

	"github.com/example/mybot/internal/domain"
	"github.com/example/mybot/internal/metrics"
)

// deliverer is the delivery layer as the pipeline sees it. The pipeline never
// formats a sentence and never imports telebot: it reports outcomes as domain
// values and sentinel errors, and the delivery layer decides what a human reads.
type deliverer interface {
	Progress(ctx context.Context, job domain.Job, state domain.State) error
	Deliver(ctx context.Context, job domain.Job, res domain.Result) (string, error)
	DeliverCached(ctx context.Context, job domain.Job, res domain.Result) error
	Fail(ctx context.Context, job domain.Job, cause error)
}

// repository is the storage layer as the pipeline sees it.
type repository interface {
	FileID(ctx context.Context, key string) (string, error)
	Save(ctx context.Context, res domain.Result) error
}

// Limits are the knobs that keep one busy user from starving everyone else.
type Limits struct {
	Workers         int
	QueueSize       int
	UserRatePerHour int
	UserBurst       int
	JobTimeout      time.Duration
}

// Pipeline accepts jobs and runs them on a bounded worker pool.
type Pipeline struct {
	repo    repository
	out     deliverer
	limits  Limits
	jobs    chan domain.Job
	buckets *userBuckets
}

// New builds the pipeline. Nothing starts until Run is called.
func New(repo repository, out deliverer, limits Limits) *Pipeline {
	return &Pipeline{
		repo:    repo,
		out:     out,
		limits:  limits,
		jobs:    make(chan domain.Job, limits.QueueSize),
		buckets: newUserBuckets(limits.UserRatePerHour, limits.UserBurst),
	}
}

// Submit queues a job, or reports why it cannot be. It never blocks: the caller
// is a Telegram handler, and a blocked handler stalls the whole update loop.
func (p *Pipeline) Submit(job domain.Job) error {
	if !p.buckets.allow(job.UserID) {
		return domain.ErrRateLimited
	}

	select {
	case p.jobs <- job:
		metrics.SetQueueDepth(len(p.jobs))
		return nil
	default:
		return domain.ErrQueueFull
	}
}

// Run starts the worker pool and serves jobs until ctx is cancelled.
func (p *Pipeline) Run(ctx context.Context) error {
	var wg sync.WaitGroup

	for i := 0; i < p.limits.Workers; i++ {
		wg.Go(func() { p.worker(ctx) })
	}

	log.Info().Int("workers", p.limits.Workers).Msg("pipeline started")
	wg.Wait()
	log.Info().Msg("pipeline stopped")

	return nil
}

func (p *Pipeline) worker(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case job := <-p.jobs:
			metrics.SetQueueDepth(len(p.jobs))
			p.handle(ctx, job)
		}
	}
}

// handle runs one job to completion. Errors are reported to the user here and
// logged once — this is the layer that understands them, so nothing above or
// below logs them again.
func (p *Pipeline) handle(ctx context.Context, job domain.Job) {
	jobCtx, cancel := context.WithTimeout(ctx, p.limits.JobTimeout)
	defer cancel()

	err := p.run(jobCtx, job)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			err = domain.ErrTimeout
		}

		metrics.IncJobFailed()
		log.Error().Err(err).Int64("user_id", job.UserID).Msg("job failed")
		p.out.Fail(ctx, job, err)

		return
	}

	metrics.IncJob()
}

func (p *Pipeline) run(ctx context.Context, job domain.Job) error {
	// Replace this with whatever identifies the work uniquely, so that an
	// identical request can be answered from Telegram's own file storage.
	key := job.Query

	fileID, err := p.repo.FileID(ctx, key)
	if err == nil {
		metrics.IncCacheHit()
		return p.out.DeliverCached(ctx, job, domain.Result{Key: key, Title: key, FileID: fileID})
	}
	if !errors.Is(err, domain.ErrNotFound) {
		return fmt.Errorf("look up cached result: %w", err)
	}

	err = p.out.Progress(ctx, job, domain.StateWorking)
	if err != nil {
		return err
	}

	// TODO: the actual work goes here, producing a domain.Result with a Path.
	res := domain.Result{Key: key, Title: key}

	err = p.out.Progress(ctx, job, domain.StateSending)
	if err != nil {
		return err
	}

	res.FileID, err = p.out.Deliver(ctx, job, res)
	if err != nil {
		return err
	}

	if res.FileID != "" {
		err = p.repo.Save(ctx, res)
		if err != nil {
			// The user already has their result; failing the job now would be
			// a lie. Losing the cache entry only costs work next time.
			log.Warn().Err(err).Str("key", key).Msg("failed to cache result")
		}
	}

	return nil
}
