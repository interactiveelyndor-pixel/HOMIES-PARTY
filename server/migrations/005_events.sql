-- Up Migration
-- Additive: product events for the core loop (find, play, rematch, connect).
-- Pseudonymous by design: a user id only, no names or text. The id is set to
-- NULL when the account is deleted, and old rows are purged (see src/events.ts).
CREATE TABLE IF NOT EXISTS events (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  props JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS events_name_time_idx ON events (name, created_at DESC);
CREATE INDEX IF NOT EXISTS events_time_idx ON events (created_at);

-- Down Migration
DROP TABLE IF EXISTS events;
