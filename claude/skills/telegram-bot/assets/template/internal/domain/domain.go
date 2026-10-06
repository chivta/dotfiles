package domain

import "time"

// Job is one unit of work accepted from a user. It carries StatusMessageID so
// the worker can edit the placeholder the handler already sent, which is what
// lets the handler return immediately instead of blocking the update loop.
type Job struct {
	UserID          int64
	ChatID          int64
	StatusMessageID int
	Query           string
	RequestedAt     time.Time
}

// State is how far along a job is. The delivery layer maps these onto text; the
// worker never formats a sentence itself.
type State int

const (
	StateQueued State = iota
	StateWorking
	StateSending
)

// Result is what a finished job produced. FileID, when set, is the Telegram
// file ID of an upload — storing it lets an identical future request skip the
// work entirely and re-send by ID.
type Result struct {
	Key    string
	Title  string
	Path   string
	FileID string
}
