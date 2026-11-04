-- Track the actual claim time so an old order does not make a fresh email send appear stale.
ALTER TABLE email_outbox ADD COLUMN last_attempt_at TEXT;
