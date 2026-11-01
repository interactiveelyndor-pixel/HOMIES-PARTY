import { FastifyInstance, FastifyReply } from 'fastify';
import { pool } from './db';
import { authenticate } from './auth';
import { getDbUser } from './rooms';
import { getFlags, minClientVersion, FLAG_KEYS } from './flags';
import { logEvent } from './events';
import { limiter } from './ratelimit';

/** Bump when the terms, community rules or privacy policy change; everyone is asked again. */
export const POLICY_KEY = 'terms_and_rules';
export const POLICY_VERSION = '1';
export const AGE_BANDS = ['under13', '13_17', '18plus'];

export interface Eligibility {
  consented: boolean;
  ageBand: string | null;
  /** May play online in private rooms. */
  online: boolean;
  /** May also meet other players (Quick Match) and use friend requests. */
  social: boolean;
}

export async function getEligibility(userId: string): Promise<Eligibility> {
  const res = await pool.query(
    `SELECT u.age_band,
            EXISTS (SELECT 1 FROM user_consents c
                    WHERE c.user_id = u.id AND c.policy_key = $2 AND c.policy_version = $3) AS consented
     FROM users u WHERE u.id = $1`,
    [userId, POLICY_KEY, POLICY_VERSION]
  );
  const row = res.rows[0];
  const consented = !!row?.consented;
  const ageBand: string | null = row?.age_band ?? null;
  return {
    consented,
    ageBand,
    online: consented && ageBand !== null,
    social: consented && (ageBand === '13_17' || ageBand === '18plus'),
  };
}

/** Sends 403 and returns false unless the user may play online. */
export async function requireOnline(userId: string, reply: FastifyReply): Promise<boolean> {
  const e = await getEligibility(userId);
  if (e.online) return true;
  await reply.status(403).send({
    error: 'Forbidden',
    code: 'CONSENT_REQUIRED',
    message: 'Please accept the terms and tell us your age range before playing online.',
  });
  return false;
}

/** Sends 403 and returns false unless the user may use social features. */
export async function requireSocial(userId: string, reply: FastifyReply): Promise<boolean> {
  const e = await getEligibility(userId);
  if (e.social) return true;
  await reply.status(403).send({
    error: 'Forbidden',
    code: e.consented ? 'SOCIAL_NOT_ALLOWED' : 'CONSENT_REQUIRED',
    message: e.consented
      ? 'Friends and matchmaking are not available for your age range.'
      : 'Please accept the terms and tell us your age range first.',
  });
  return false;
}

export async function eligibilityRoutes(server: FastifyInstance): Promise<void> {
  // Public: lets the app decide what to show before anyone signs in.
  server.get('/v1/config', async () => {
    return {
      policyKey: POLICY_KEY,
      policyVersion: POLICY_VERSION,
      minClientVersion: minClientVersion(),
      features: await getFlags(),
    };
  });

  server.get('/v1/me/eligibility', { preHandler: authenticate }, async (request, reply) => {
    const user = await getDbUser(request, reply);
    if (!user) return;
    return { ...(await getEligibility(user.id)), policyVersion: POLICY_VERSION };
  });

  server.post('/v1/me/consent', { preHandler: authenticate }, async (request, reply) => {
    const user = await getDbUser(request, reply);
    if (!user) return;
    const body = (request.body ?? {}) as any;
    if (body.policyVersion !== POLICY_VERSION) {
      return reply.status(400).send({ error: 'Bad Request', message: 'These terms are out of date. Please reopen the app.' });
    }
    if (!AGE_BANDS.includes(body.ageBand)) {
      return reply.status(400).send({ error: 'Bad Request', message: `ageBand must be one of: ${AGE_BANDS.join(', ')}.` });
    }
    // Once someone says they are under 13 that stays, so the answer cannot just be changed to unlock features.
    const current = await pool.query('SELECT age_band FROM users WHERE id = $1', [user.id]);
    if (current.rows[0]?.age_band === 'under13' && body.ageBand !== 'under13') {
      return reply.status(409).send({ error: 'Conflict', message: 'Your age range cannot be changed.' });
    }
    await pool.query('UPDATE users SET age_band = $2 WHERE id = $1', [user.id, body.ageBand]);
    await pool.query(
      `INSERT INTO user_consents (user_id, policy_key, policy_version) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
      [user.id, POLICY_KEY, POLICY_VERSION]
    );
    logEvent('consent_accepted', user.id, { policyVersion: POLICY_VERSION, ageBand: body.ageBand });
    return { ...(await getEligibility(user.id)), policyVersion: POLICY_VERSION };
  });

  // Everything we hold about the caller, as JSON they can keep.
  server.get('/v1/me/export', { preHandler: authenticate }, async (request, reply) => {
    const user = await getDbUser(request, reply);
    if (!user) return;
    if (!limiter.allow(`export:${user.id}`, 3, 3_600_000)) {
      return reply.status(429).send({ error: 'Too Many Requests', message: 'You can export your data 3 times an hour.' });
    }
    const q = async (sql: string) => (await pool.query(sql, [user.id])).rows;
    return {
      exportedAt: new Date().toISOString(),
      profile: { id: user.id, nickname: user.nickname, avatar: user.avatar, createdAt: user.created_at },
      eligibility: await getEligibility(user.id),
      consents: await q('SELECT policy_key, policy_version, accepted_at FROM user_consents WHERE user_id = $1'),
      friends: await q(
        `SELECT u.id, u.nickname FROM friendships f
         JOIN users u ON u.id = CASE WHEN f.user_a = $1 THEN f.user_b ELSE f.user_a END
         WHERE f.user_a = $1 OR f.user_b = $1`
      ),
      blocked: await q('SELECT blocked_id FROM blocks WHERE blocker_id = $1'),
      recentPlayers: await q('SELECT other_id, last_played_at FROM recent_players WHERE user_id = $1'),
      reportsFiled: await q('SELECT reported_id, reason, created_at FROM reports WHERE reporter_id = $1'),
      xp: await q('SELECT game_type, reason, amount, created_at FROM xp_ledger WHERE user_id = $1 ORDER BY created_at DESC LIMIT 500'),
      events: await q('SELECT name, props, created_at FROM events WHERE user_id = $1 ORDER BY created_at DESC LIMIT 500'),
    };
  });
}

export { FLAG_KEYS };
