-- Up Migration
-- Additive: policy consent + age band, runtime feature flags, and host kicks.

ALTER TABLE users ADD COLUMN IF NOT EXISTS age_band TEXT; -- under13 | 13_17 | 18plus

CREATE TABLE IF NOT EXISTS user_consents (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  policy_key TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, policy_key, policy_version)
);

-- Overrides for environment defaults, so a feature can be switched off (or on)
-- while the server is running, without a new app build.
CREATE TABLE IF NOT EXISTS feature_flags (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- A player the host removed cannot rejoin that room.
CREATE TABLE IF NOT EXISTS room_kicks (
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (room_id, user_id)
);

-- Down Migration
DROP TABLE IF EXISTS room_kicks;
DROP TABLE IF EXISTS feature_flags;
DROP TABLE IF EXISTS user_consents;
ALTER TABLE users DROP COLUMN IF EXISTS age_band;
