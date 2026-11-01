-- Up Migration
-- Additive: a suspension flag, and reports that survive deletion of the reporter.
ALTER TABLE users ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;

ALTER TABLE reports ALTER COLUMN reporter_id DROP NOT NULL;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
ALTER TABLE reports
  ADD CONSTRAINT reports_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL;

-- Down Migration
-- Reports whose reporter was deleted cannot satisfy NOT NULL, so drop them first.
DELETE FROM reports WHERE reporter_id IS NULL;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
ALTER TABLE reports
  ADD CONSTRAINT reports_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE reports ALTER COLUMN reporter_id SET NOT NULL;
ALTER TABLE users DROP COLUMN IF EXISTS banned_at;
