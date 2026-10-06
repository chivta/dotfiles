package metrics

import (
	"fmt"
	"net/http"
	"sync/atomic"
)

// Counters are process-wide, following the same "initialise once, call via
// package functions" rule as the logger. Rename these to whatever this bot
// actually does — the set below is the minimum worth having.
var (
	requestsTotal    atomic.Int64
	requestsRejected atomic.Int64
	jobsTotal        atomic.Int64
	jobsFailed       atomic.Int64
	cacheHits        atomic.Int64
	queueDepth       atomic.Int64
	errorsTotal      atomic.Int64
)

// IncRequest records a request accepted from a user.
func IncRequest() { requestsTotal.Add(1) }

// IncRejected records a request turned away by rate limiting or a full queue.
func IncRejected() { requestsRejected.Add(1) }

// IncJob records a job that finished and was delivered.
func IncJob() { jobsTotal.Add(1) }

// IncJobFailed records a job that ended without a delivery.
func IncJobFailed() { jobsFailed.Add(1) }

// IncCacheHit records a result re-sent from a stored Telegram file ID, which
// skips the work entirely.
func IncCacheHit() { cacheHits.Add(1) }

// SetQueueDepth publishes how many jobs are waiting for a worker.
func SetQueueDepth(n int) { queueDepth.Store(int64(n)) }

// IncErrors records an error-level event. Called by the logging hook, not
// directly.
func IncErrors() { errorsTotal.Add(1) }

// Handler renders the counters in Prometheus text exposition format. Hand-rolled
// because a handful of atomics does not justify the client library's weight.
func Handler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("content-type", "text/plain; version=0.0.4")

		fmt.Fprintf(w, "# TYPE mybot_requests_total counter\nmybot_requests_total %d\n", requestsTotal.Load())
		fmt.Fprintf(w, "# TYPE mybot_requests_rejected_total counter\nmybot_requests_rejected_total %d\n", requestsRejected.Load())
		fmt.Fprintf(w, "# TYPE mybot_jobs_total counter\nmybot_jobs_total %d\n", jobsTotal.Load())
		fmt.Fprintf(w, "# TYPE mybot_jobs_failed_total counter\nmybot_jobs_failed_total %d\n", jobsFailed.Load())
		fmt.Fprintf(w, "# TYPE mybot_cache_hits_total counter\nmybot_cache_hits_total %d\n", cacheHits.Load())
		fmt.Fprintf(w, "# TYPE mybot_queue_depth gauge\nmybot_queue_depth %d\n", queueDepth.Load())
		fmt.Fprintf(w, "# TYPE mybot_errors_total counter\nmybot_errors_total %d\n", errorsTotal.Load())
	})
}
