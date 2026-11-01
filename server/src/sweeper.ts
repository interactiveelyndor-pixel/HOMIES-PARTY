import { pool } from './db';
import { runGameAction } from './gameRuntime';
import { disconnectedLongerThan, forget } from './presence';
import { getRoomDetailsById } from './rooms';
import { broadcastRoomUpdated, emitToRoom } from './socket';

// How long a player may stay disconnected from a running game before they forfeit.
const grace = () => Number(process.env.DISCONNECT_GRACE_MS) || 90_000;
const LOBBY_MINUTES = Number(process.env.ROOM_EXPIRY_MINUTES) || 45;
const STALE_GAME_HOURS = 12;

/** Applies "turn expired" for the server, so a game keeps moving with nobody's app open. */
async function expireTurns(now: number): Promise<number> {
  const due = await pool.query(
    `SELECT code FROM rooms
     WHERE status = 'playing' AND (game_state->>'turnDeadline')::bigint < $1
     LIMIT 50`,
    [now]
  );
  let applied = 0;
  for (const { code } of due.rows) {
    const out = await runGameAction({
      code,
      actorId: null,
      event: 'game:skip',
      compute: (mod, room, active, t) => mod.skip(room.game_state, new Set(active), t),
    });
    if (out.ok) applied++;
  }
  return applied;
}

/** Removes players who have been disconnected longer than the grace period from their running games. */
async function forfeitDisconnected(now: number): Promise<number> {
  let forfeits = 0;
  for (const userId of disconnectedLongerThan(grace(), now)) {
    const rooms = await pool.query(
      `SELECT r.id, r.code FROM rooms r
       JOIN room_players rp ON rp.room_id = r.id AND rp.user_id = $1
       WHERE r.status = 'playing'`,
      [userId]
    );
    for (const room of rooms.rows) {
      await pool.query('DELETE FROM room_players WHERE room_id = $1 AND user_id = $2', [room.id, userId]);
      // Hand the host role to the earliest remaining player.
      await pool.query(
        `UPDATE rooms SET host_user_id = (
           SELECT user_id FROM room_players WHERE room_id = $1 ORDER BY joined_at ASC LIMIT 1)
         WHERE id = $1 AND host_user_id = $2
           AND EXISTS (SELECT 1 FROM room_players WHERE room_id = $1)`,
        [room.id, userId]
      );
      // Force the game to notice (it settles leavers when a turn expires).
      await pool.query(
        `UPDATE rooms SET game_state = jsonb_set(game_state, '{turnDeadline}', '0') WHERE id = $1`,
        [room.id]
      );
      await runGameAction({
        code: room.code,
        actorId: null,
        event: 'game:skip',
        compute: (mod, r, active, t) => mod.skip(r.game_state, new Set(active), t),
      });
      const details = await getRoomDetailsById(room.id);
      if (details) broadcastRoomUpdated(details.code, details);
      forfeits++;
    }
    forget(userId);
  }
  return forfeits;
}

/** Closes lobbies nobody started and clears very old games. */
async function expireRooms(): Promise<number> {
  const closed = await pool.query(
    `DELETE FROM rooms
     WHERE (status = 'lobby' AND created_at < NOW() - ($1::int * INTERVAL '1 minute'))
        OR (status IN ('playing', 'finished') AND created_at < NOW() - ($2::int * INTERVAL '1 hour'))
     RETURNING code`,
    [LOBBY_MINUTES, STALE_GAME_HOURS]
  );
  for (const { code } of closed.rows) emitToRoom(code, 'room:closed', { code });
  return closed.rowCount ?? 0;
}

export async function sweepOnce(now = Date.now()): Promise<{ turns: number; forfeits: number; rooms: number }> {
  return {
    turns: await expireTurns(now),
    forfeits: await forfeitDisconnected(now),
    rooms: await expireRooms(),
  };
}

/** Runs every few seconds. The timer does not keep the process alive. */
export function startSweeper(): void {
  const every = Number(process.env.SWEEP_MS) || 5_000;
  setInterval(() => {
    sweepOnce().catch(() => {});
  }, every).unref();
}
