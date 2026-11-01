-- Up Migration
-- Additive only: existing rows keep working (game_type defaults to 'snl').
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS game_type TEXT NOT NULL DEFAULT 'snl';
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS game_state JSONB;

-- Down Migration
ALTER TABLE rooms DROP COLUMN IF EXISTS game_state;
ALTER TABLE rooms DROP COLUMN IF EXISTS game_type;
