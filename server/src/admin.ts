import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { timingSafeEqual } from 'crypto';
import { pool } from './db';
import { isUuid } from './ratelimit';
import { FLAG_KEYS, FlagKey, getFlags, setFlag } from './flags';

/**
 * Minimal moderation API. Registered only when ADMIN_TOKEN (16+ chars) is set,
 * so it does not exist on a server that has not opted in.
 * shortcut: one shared secret and no audit log; replace with real admin
 * accounts before more than one person moderates.
 */
export async function adminRoutes(server: FastifyInstance, { token }: { token: string }): Promise<void> {
  const expected = Buffer.from(token);
  const guard = async (request: FastifyRequest, reply: FastifyReply) => {
    const given = Buffer.from(String(request.headers['x-admin-token'] ?? ''));
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
      return reply.status(401).send({ error: 'Unauthorized', message: 'Invalid admin token.' });
    }
  };
  const opts = { preHandler: guard };
  const bad = (reply: FastifyReply, message: string) => reply.status(400).send({ error: 'Bad Request', message });

  // Plain counts of product events, no interpretation. ?days=1..365 (default 7).
  server.get('/admin/stats', opts, async (request, reply) => {
    const raw = (request.query as any)?.days;
    const days = raw === undefined ? 7 : Number(raw);
    if (!Number.isInteger(days) || days < 1 || days > 365) return bad(reply, 'days must be 1 to 365.');
    const since = `NOW() - ($1::int * INTERVAL '1 day')`;
    const events = await pool.query(
      `SELECT name, COUNT(*)::int AS events, COUNT(DISTINCT user_id)::int AS users
       FROM events WHERE created_at > ${since} GROUP BY name ORDER BY name`,
      [days]
    );
    const byGame = await pool.query(
      `SELECT props->>'gameType' AS game, name, COUNT(*)::int AS events
       FROM events
       WHERE created_at > ${since} AND props ? 'gameType'
       GROUP BY 1, 2 ORDER BY 1, 2`,
      [days]
    );
    return { days, events: events.rows, byGame: byGame.rows };
  });

  // The kill switch: read or change a feature flag while the server is running.
  server.get('/admin/flags', opts, async () => ({ flags: await getFlags() }));

  server.post('/admin/flags/:key', opts, async (request, reply) => {
    const { key } = request.params as any;
    const enabled = (request.body as any)?.enabled;
    if (!(FLAG_KEYS as string[]).includes(key)) return bad(reply, `Unknown flag. Known: ${FLAG_KEYS.join(', ')}.`);
    if (typeof enabled !== 'boolean') return bad(reply, 'enabled must be true or false.');
    await setFlag(key as FlagKey, enabled);
    return { flags: await getFlags() };
  });

  server.get('/admin/reports', opts, async (request) => {
    const status = (request.query as any)?.status === 'all' ? null : ((request.query as any)?.status ?? 'open');
    const res = await pool.query(
      `SELECT r.id, r.status, r.reason, r.details, r.created_at,
              r.reporter_id, rep.nickname AS reporter_nickname,
              r.reported_id, tgt.nickname AS reported_nickname, tgt.banned_at IS NOT NULL AS reported_banned,
              (SELECT COUNT(*)::int FROM reports o WHERE o.reported_id = r.reported_id) AS reports_against
       FROM reports r
       LEFT JOIN users rep ON rep.id = r.reporter_id
       LEFT JOIN users tgt ON tgt.id = r.reported_id
       WHERE ($1::text IS NULL OR r.status = $1)
       ORDER BY r.created_at ASC
       LIMIT 100`,
      [status]
    );
    return { reports: res.rows };
  });

  server.post('/admin/reports/:id/resolve', opts, async (request, reply) => {
    const { id } = request.params as any;
    const status = (request.body as any)?.status;
    if (!isUuid(id)) return bad(reply, 'Invalid report id.');
    if (status !== 'dismissed' && status !== 'actioned') return bad(reply, "status must be 'dismissed' or 'actioned'.");
    const res = await pool.query('UPDATE reports SET status = $2 WHERE id = $1', [id, status]);
    if (!res.rowCount) return reply.status(404).send({ error: 'Not Found', message: 'Report not found.' });
    return { message: 'Updated.' };
  });

  for (const [action, value] of [['ban', 'NOW()'], ['unban', 'NULL']] as const) {
    server.post(`/admin/users/:id/${action}`, opts, async (request, reply) => {
      const { id } = request.params as any;
      if (!isUuid(id)) return bad(reply, 'Invalid user id.');
      const res = await pool.query(`UPDATE users SET banned_at = ${value} WHERE id = $1`, [id]);
      if (!res.rowCount) return reply.status(404).send({ error: 'Not Found', message: 'User not found.' });
      return { message: action === 'ban' ? 'User suspended.' : 'User restored.' };
    });
  }
}
