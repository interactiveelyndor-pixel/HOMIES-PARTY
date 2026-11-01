import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { pool } from './db';
import { authenticate } from './auth';
import { getDbUser, DbUser } from './rooms';
import { limiter, isUuid } from './ratelimit';
import { logEvent } from './events';
import { requireSocial } from './eligibility';

export const REPORT_REASONS = ['harassment', 'cheating', 'inappropriate_name', 'spam', 'other'];
const HOUR = 3_600_000;
const NOT_FOUND = { error: 'Not Found', message: 'Player not found.' };

const bad = (reply: FastifyReply, message: string) =>
  reply.status(400).send({ error: 'Bad Request', message });
const tooMany = (reply: FastifyReply) =>
  reply.status(429).send({ error: 'Too Many Requests', message: 'Too many requests. Please try again later.' });

/** True if either user has blocked the other. */
async function isBlockedEitherWay(a: string, b: string): Promise<boolean> {
  const r = await pool.query(
    `SELECT 1 FROM blocks
     WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1) LIMIT 1`,
    [a, b]
  );
  return r.rows.length > 0;
}

async function hasPlayedWith(me: string, other: string): Promise<boolean> {
  const r = await pool.query('SELECT 1 FROM recent_players WHERE user_id = $1 AND other_id = $2', [me, other]);
  return r.rows.length > 0;
}

export async function socialRoutes(server: FastifyInstance): Promise<void> {
  // Wraps a handler: authenticates, loads the DB user, and turns throws into 500s.
  const route = (
    handler: (user: DbUser, request: FastifyRequest, reply: FastifyReply) => Promise<unknown>
  ) => async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;
      return await handler(user, request, reply);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({ error: 'Internal Server Error', message: 'Request failed.' });
    }
  };
  const opts = { preHandler: authenticate };

  // --- Recent players (excludes anyone blocked in either direction) ---
  server.get('/v1/players/recent', opts, route(async (user) => {
    const res = await pool.query(
      `SELECT rp.other_id AS user_id, u.nickname, u.avatar, rp.last_played_at,
         CASE
           WHEN EXISTS (SELECT 1 FROM friendships f
                        WHERE f.user_a = LEAST($1::uuid, rp.other_id) AND f.user_b = GREATEST($1::uuid, rp.other_id)) THEN 'friend'
           WHEN EXISTS (SELECT 1 FROM friend_requests q WHERE q.from_user = $1 AND q.to_user = rp.other_id) THEN 'pending_out'
           WHEN EXISTS (SELECT 1 FROM friend_requests q WHERE q.from_user = rp.other_id AND q.to_user = $1) THEN 'pending_in'
           ELSE 'none'
         END AS relation
       FROM recent_players rp
       JOIN users u ON u.id = rp.other_id
       WHERE rp.user_id = $1
         AND NOT EXISTS (SELECT 1 FROM blocks b
                         WHERE (b.blocker_id = $1 AND b.blocked_id = rp.other_id)
                            OR (b.blocker_id = rp.other_id AND b.blocked_id = $1))
       ORDER BY rp.last_played_at DESC
       LIMIT 30`,
      [user.id]
    );
    return { players: res.rows.map(toPlayer) };
  }));

  // --- Friends ---
  server.get('/v1/friends', opts, route(async (user) => {
    const res = await pool.query(
      `SELECT u.id AS user_id, u.nickname, u.avatar, 'friend' AS relation
       FROM friendships f
       JOIN users u ON u.id = CASE WHEN f.user_a = $1 THEN f.user_b ELSE f.user_a END
       WHERE f.user_a = $1 OR f.user_b = $1
       ORDER BY u.nickname ASC
       LIMIT 200`,
      [user.id]
    );
    return { friends: res.rows.map(toPlayer) };
  }));

  server.delete('/v1/friends/:userId', opts, route(async (user, request, reply) => {
    const { userId } = request.params as any;
    if (!isUuid(userId)) return bad(reply, 'Invalid user id.');
    await pool.query(
      'DELETE FROM friendships WHERE user_a = LEAST($1::uuid, $2::uuid) AND user_b = GREATEST($1::uuid, $2::uuid)',
      [user.id, userId]
    );
    return reply.status(200).send({ message: 'Removed.' });
  }));

  server.get('/v1/friends/requests', opts, route(async (user) => {
    const incoming = await pool.query(
      `SELECT q.id AS request_id, u.id AS user_id, u.nickname, u.avatar, 'pending_in' AS relation
       FROM friend_requests q JOIN users u ON u.id = q.from_user
       WHERE q.to_user = $1 ORDER BY q.created_at DESC LIMIT 100`,
      [user.id]
    );
    const outgoing = await pool.query(
      `SELECT q.id AS request_id, u.id AS user_id, u.nickname, u.avatar, 'pending_out' AS relation
       FROM friend_requests q JOIN users u ON u.id = q.to_user
       WHERE q.from_user = $1 ORDER BY q.created_at DESC LIMIT 100`,
      [user.id]
    );
    return { incoming: incoming.rows.map(toPlayer), outgoing: outgoing.rows.map(toPlayer) };
  }));

  server.post('/v1/friends/requests', opts, route(async (user, request, reply) => {
    if (!(await requireSocial(user.id, reply))) return;
    const target = (request.body as any)?.userId;
    if (!isUuid(target)) return bad(reply, 'userId is required.');
    if (target === user.id) return bad(reply, 'You cannot add yourself.');
    if (!limiter.allow(`friend-req:${user.id}`, 20, HOUR)) return tooMany(reply);

    // Same answer for "unknown", "never played with" and "blocked" so nothing leaks.
    if (!(await hasPlayedWith(user.id, target)) || (await isBlockedEitherWay(user.id, target))) {
      return reply.status(404).send(NOT_FOUND);
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const friends = await client.query(
        'SELECT 1 FROM friendships WHERE user_a = LEAST($1::uuid, $2::uuid) AND user_b = GREATEST($1::uuid, $2::uuid)',
        [user.id, target]
      );
      if (friends.rows.length) {
        await client.query('ROLLBACK');
        return reply.status(409).send({ error: 'Conflict', message: 'You are already friends.' });
      }

      // They already asked us: treat as acceptance (mutual consent).
      const reverse = await client.query(
        'DELETE FROM friend_requests WHERE from_user = $1 AND to_user = $2 RETURNING id',
        [target, user.id]
      );
      if (reverse.rows.length) {
        await client.query(
          `INSERT INTO friendships (user_a, user_b) VALUES (LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid))
           ON CONFLICT DO NOTHING`,
          [user.id, target]
        );
        await client.query('COMMIT');
        logEvent('friend_request_accepted', user.id, { via: 'crossing_requests' });
        return reply.status(200).send({ status: 'friends' });
      }

      const pending = await client.query('SELECT COUNT(*)::int AS n FROM friend_requests WHERE from_user = $1', [user.id]);
      if (pending.rows[0].n >= 50) {
        await client.query('ROLLBACK');
        return tooMany(reply);
      }

      const ins = await client.query(
        'INSERT INTO friend_requests (from_user, to_user) VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING id',
        [user.id, target]
      );
      if (!ins.rows.length) {
        await client.query('ROLLBACK');
        return reply.status(409).send({ error: 'Conflict', message: 'Friend request already sent.' });
      }
      await client.query('COMMIT');
      logEvent('friend_request_sent', user.id);
      return reply.status(201).send({ status: 'pending' });
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }));

  server.post('/v1/friends/requests/:id/accept', opts, route(async (user, request, reply) => {
    if (!(await requireSocial(user.id, reply))) return;
    const { id } = request.params as any;
    if (!isUuid(id)) return bad(reply, 'Invalid request id.');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const del = await client.query(
        'DELETE FROM friend_requests WHERE id = $1 AND to_user = $2 RETURNING from_user',
        [id, user.id]
      );
      if (!del.rows.length) {
        await client.query('ROLLBACK');
        return reply.status(404).send({ error: 'Not Found', message: 'Friend request not found.' });
      }
      await client.query(
        `INSERT INTO friendships (user_a, user_b) VALUES (LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid))
         ON CONFLICT DO NOTHING`,
        [user.id, del.rows[0].from_user]
      );
      await client.query('COMMIT');
      logEvent('friend_request_accepted', user.id, { via: 'accept' });
      return { status: 'friends' };
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }));

  // Decline (recipient) or cancel (sender).
  server.delete('/v1/friends/requests/:id', opts, route(async (user, request, reply) => {
    const { id } = request.params as any;
    if (!isUuid(id)) return bad(reply, 'Invalid request id.');
    const del = await pool.query(
      'DELETE FROM friend_requests WHERE id = $1 AND (to_user = $2 OR from_user = $2)',
      [id, user.id]
    );
    if (!del.rowCount) return reply.status(404).send({ error: 'Not Found', message: 'Friend request not found.' });
    return { message: 'Removed.' };
  }));

  // --- Blocks ---
  server.get('/v1/blocks', opts, route(async (user) => {
    const res = await pool.query(
      `SELECT u.id AS user_id, u.nickname, u.avatar, 'blocked' AS relation
       FROM blocks b JOIN users u ON u.id = b.blocked_id
       WHERE b.blocker_id = $1 ORDER BY b.created_at DESC LIMIT 200`,
      [user.id]
    );
    return { blocked: res.rows.map(toPlayer) };
  }));

  server.post('/v1/blocks', opts, route(async (user, request, reply) => {
    const target = (request.body as any)?.userId;
    if (!isUuid(target)) return bad(reply, 'userId is required.');
    if (target === user.id) return bad(reply, 'You cannot block yourself.');
    if (!limiter.allow(`block:${user.id}`, 60, HOUR)) return tooMany(reply);

    const exists = await pool.query('SELECT 1 FROM users WHERE id = $1', [target]);
    if (!exists.rows.length) return reply.status(404).send(NOT_FOUND);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [user.id, target]);
      // Blocking ends any friendship and pending request in both directions.
      await client.query(
        'DELETE FROM friendships WHERE user_a = LEAST($1::uuid, $2::uuid) AND user_b = GREATEST($1::uuid, $2::uuid)',
        [user.id, target]
      );
      await client.query(
        `DELETE FROM friend_requests
         WHERE (from_user = $1 AND to_user = $2) OR (from_user = $2 AND to_user = $1)`,
        [user.id, target]
      );
      await client.query('COMMIT');
      return reply.status(201).send({ message: 'Blocked.' });
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }));

  server.delete('/v1/blocks/:userId', opts, route(async (user, request, reply) => {
    const { userId } = request.params as any;
    if (!isUuid(userId)) return bad(reply, 'Invalid user id.');
    await pool.query('DELETE FROM blocks WHERE blocker_id = $1 AND blocked_id = $2', [user.id, userId]);
    return { message: 'Unblocked.' };
  }));

  // --- Reports ---
  server.post('/v1/reports', opts, route(async (user, request, reply) => {
    const body = (request.body ?? {}) as any;
    if (!isUuid(body.userId)) return bad(reply, 'userId is required.');
    if (body.userId === user.id) return bad(reply, 'You cannot report yourself.');
    if (!REPORT_REASONS.includes(body.reason)) {
      return bad(reply, `reason must be one of: ${REPORT_REASONS.join(', ')}.`);
    }
    if (body.details !== undefined && (typeof body.details !== 'string' || body.details.length > 500)) {
      return bad(reply, 'details must be text of at most 500 characters.');
    }
    if (!limiter.allow(`report:${user.id}`, 10, HOUR)) return tooMany(reply);
    // Only players you actually shared a game with can be reported.
    if (!(await hasPlayedWith(user.id, body.userId))) return reply.status(404).send(NOT_FOUND);

    await pool.query(
      'INSERT INTO reports (reporter_id, reported_id, reason, details) VALUES ($1, $2, $3, $4)',
      [user.id, body.userId, body.reason, body.details?.trim() || null]
    );
    return reply.status(201).send({ message: 'Report received. Thank you.' });
  }));
}

function toPlayer(row: any) {
  return {
    userId: row.user_id,
    nickname: row.nickname,
    avatar: row.avatar,
    relation: row.relation,
    ...(row.request_id ? { requestId: row.request_id } : {}),
  };
}
