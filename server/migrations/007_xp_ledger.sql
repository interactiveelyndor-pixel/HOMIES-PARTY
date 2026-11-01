-- Up Migration
-- Additive: one row per reward. The unique key makes awarding idempotent.
CREATE TABLE IF NOT EXISTS xp_ledger (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  game_type TEXT NOT NULL,
  match_key INT NOT NULL,          -- game_state.version when the game ended
  reason TEXT NOT NULL,            -- win | draw | played
  amount INT NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS xp_ledger_once ON xp_ledger (user_id, room_id, match_key);
CREATE INDEX IF NOT EXISTS xp_ledger_user ON xp_ledger (user_id, created_at);

-- Down Migration
DROP TABLE IF EXISTS xp_ledger;
