-- Up Migration
-- Additive: a party room runs several rounds of random games; this holds its schedule and score.
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS party JSONB;

-- Down Migration
ALTER TABLE rooms DROP COLUMN IF EXISTS party;
