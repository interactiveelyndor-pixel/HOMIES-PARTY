import { FastifyInstance } from 'fastify';
import { PoolClient } from 'pg';
import { pool } from './db';
import { authenticate } from './auth';
import { getDbUser } from './rooms';

const XP = { win: 30, draw: 15, played: 10 };
/** Stops XP farming with throwaway private rooms. shortcut: per-user daily cap only, no per-pair check; add one if abused. */
export const DAILY_XP_CAP = 300;

export const levelOf = (xp: number) => Math.floor(Math.sqrt(xp / 50)) + 1;
const xpForLevel = (level: number) => 50 * (level - 1) ** 2;

/**
 * Rewards everyone still in the room when a game ends (leavers get nothing).
 * Runs inside the game's own transaction, so a finished game and its XP stay in step.
 */
export async function awardMatchXp(
  client: PoolClient,
  roomId: string,
  gameType: string,
  matchKey: number,
  winnerId: string | null,
  memberIds: string[]
): Promise<void> {
  for (const userId of memberIds) {
    const reason = winnerId === userId ? 'win' : winnerId ? 'played' : 'draw';
    const today = await client.query(
      `SELECT COALESCE(SUM(amount), 0)::int AS xp FROM xp_ledger WHERE user_id = $1 AND created_at > NOW() - INTERVAL '1 day'`,
      [userId]
    );
    const amount = Math.max(0, Math.min(XP[reason as keyof typeof XP], DAILY_XP_CAP - today.rows[0].xp));
    await client.query(
      `INSERT INTO xp_ledger (user_id, room_id, game_type, match_key, reason, amount)
       VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT DO NOTHING`,
      [userId, roomId, gameType, matchKey, reason, amount]
    );
  }
}

export async function getProgress(userId: string) {
  const r = await pool.query(
    `SELECT COALESCE(SUM(amount), 0)::int AS xp, COUNT(*)::int AS played,
            COUNT(*) FILTER (WHERE reason = 'win')::int AS wins
     FROM xp_ledger WHERE user_id = $1`,
    [userId]
  );
  const { xp, played, wins } = r.rows[0];
  const level = levelOf(xp);
  return { xp, level, levelStartXp: xpForLevel(level), nextLevelXp: xpForLevel(level + 1), played, wins };
}

export async function progressRoutes(server: FastifyInstance): Promise<void> {
  server.get('/v1/me/progress', { preHandler: authenticate }, async (request, reply) => {
    const user = await getDbUser(request, reply);
    if (!user) return;
    return getProgress(user.id);
  });
}
