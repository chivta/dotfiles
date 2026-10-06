package storage

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/example/mybot/internal/domain"
)

// ResultRepo stores the Telegram file ID of every delivered result.
type ResultRepo struct {
	db *sql.DB
}

// NewResultRepo builds a repository over an open database handle.
func NewResultRepo(db *sql.DB) *ResultRepo {
	return &ResultRepo{db: db}
}

// FileID returns the Telegram file ID of an already delivered result, or
// domain.ErrNotFound when it has never been sent.
//
// Translating sql.ErrNoRows here is the point of the repository: no layer above
// this one should have to import database/sql to understand a result.
func (r *ResultRepo) FileID(ctx context.Context, key string) (string, error) {
	var fileID string
	err := r.db.QueryRowContext(ctx, `SELECT file_id FROM results WHERE key = ?`, key).Scan(&fileID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", domain.ErrNotFound
		}
		return "", fmt.Errorf("query result: %w", err)
	}

	return fileID, nil
}

// Save records a delivered result. One re-uploaded under a new file ID replaces
// the old row.
func (r *ResultRepo) Save(ctx context.Context, res domain.Result) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO results (key, title, file_id, created_at) VALUES (?, ?, ?, ?)
		 ON CONFLICT(key) DO UPDATE SET
		     title = excluded.title, file_id = excluded.file_id`,
		res.Key, res.Title, res.FileID, time.Now().Unix(),
	)
	if err != nil {
		return fmt.Errorf("insert result: %w", err)
	}

	return nil
}
