-- Delivered results, keyed by whatever identifies the work uniquely. file_id is
-- Telegram's own handle for an uploaded file: keeping it lets an identical
-- future request skip the work and re-send by ID for one API call.
CREATE TABLE results (
    key        TEXT PRIMARY KEY,
    title      TEXT NOT NULL,
    file_id    TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE INDEX results_created_at_idx ON results (created_at);
