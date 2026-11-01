import { pool } from './db';

/** Events older than this are deleted. */
export const EVENT_RETENTION_DAYS = 180;

/**
 * Records a product event. Fire-and-forget: analytics must never slow down or
 * break a game, so failures are swallowed. Keep props small and free of
 * personal data (game ids, counts, outcomes).
 */
export function logEvent(name: string, userId: string | null, props: Record<string, unknown> = {}): void {
  pool
    .query('INSERT INTO events (name, user_id, props) VALUES ($1, $2, $3)', [name, userId, JSON.stringify(props)])
    .catch(() => {});
}

export async function purgeOldEvents(): Promise<number> {
  const res = await pool.query(`DELETE FROM events WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`, [
    EVENT_RETENTION_DAYS,
  ]);
  return res.rowCount ?? 0;
}

/** Purges now and then daily. The timer does not keep the process alive. */
export function startEventRetention(): void {
  const run = () => purgeOldEvents().catch(() => {});
  run();
  setInterval(run, 24 * 60 * 60 * 1000).unref();
}
