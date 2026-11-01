import { awardMatchXp } from './progress';
import { pool } from './db';
import { logEvent } from './events';
import { getGame } from './games/registry';
import { BaseState, GameModule, GameResult, isOver } from './games/types';
import { broadcastGameState, broadcastRoomStarted, broadcastRoomUpdated } from './socket';
import { getRoomDetailsById } from './rooms';
import { PartyState, pickGame, scoreRound } from './party';

export interface ActionOptions {
  code: string;
  /** The player acting, or null when the server itself acts (timers, forfeits). */
  actorId: string | null;
  /** Socket event name, used for analytics ('game:rematch' etc). */
  event: string;
  /** Revision the client was looking at; the action is refused if the game has moved on. */
  expectedRevision?: unknown;
  compute: (mod: GameModule<BaseState>, room: any, active: string[], now: number) => GameResult<BaseState>;
}

export type ActionOutcome =
  | { ok: true; state: BaseState }
  | { ok: false; error: string; message: string; code?: string };

const fail = (error: string, message: string, code?: string): ActionOutcome => ({ ok: false, error, message, code });

/**
 * One game action in one locked transaction: find the room, check the actor,
 * apply the rule, save, then tell everyone. Used by player actions (sockets)
 * and by the server's own timers.
 */
export async function runGameAction(opts: ActionOptions): Promise<ActionOutcome> {
  const { actorId, event } = opts;
  const code = opts.code.trim().toUpperCase();
  if (!code) return fail('Bad Request', 'Room code is required.');
  if (opts.expectedRevision !== undefined && opts.expectedRevision !== null &&
      !Number.isInteger(opts.expectedRevision)) {
    return fail('Bad Request', 'expectedRevision must be a whole number.');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const roomRes = await client.query(
      `SELECT id, status, game_type, game_state, party FROM rooms WHERE UPPER(code) = $1 FOR UPDATE`,
      [code]
    );
    const room = roomRes.rows[0];
    if (!room) { await client.query('ROLLBACK'); return fail('Not Found', 'Room not found.'); }

    const members = await client.query(
      'SELECT user_id FROM room_players WHERE room_id = $1 ORDER BY joined_at ASC', [room.id]);
    const active: string[] = members.rows.map((r: any) => r.user_id);

    if (actorId) {
      // A suspension applies to sockets that connected before it happened.
      const banned = await client.query('SELECT 1 FROM users WHERE id = $1 AND banned_at IS NOT NULL', [actorId]);
      if (banned.rows.length) { await client.query('ROLLBACK'); return fail('Forbidden', 'This account has been suspended.'); }
      if (!active.includes(actorId)) { await client.query('ROLLBACK'); return fail('Forbidden', 'You are not a member of this room.'); }
    }

    const mod = getGame(room.game_type);
    if (!mod || !room.game_state) {
      await client.query('ROLLBACK');
      return fail('Conflict', 'No game is in progress in this room.');
    }
    const party: PartyState | null = room.party ?? null;
    const prevState = room.game_state as BaseState;

    // Refuse an action based on an old view (a delayed or repeated tap).
    if (actorId && opts.expectedRevision !== undefined && opts.expectedRevision !== null &&
        opts.expectedRevision !== (room.game_state as BaseState).version) {
      await client.query('ROLLBACK');
      return fail('Conflict', 'The game moved on. Refreshing.', 'REVISION_CONFLICT');
    }

    // Party Mode: "rematch" means the next round, with a different random game.
    if (party && event === 'game:rematch') {
      const err =
        room.status !== 'finished' ? 'The next round starts after this game ends.'
        : party.finished ? 'The party is over.'
        : null;
      const next = err ? null : pickGame(active.length, room.game_type);
      const nextMod = next ? getGame(next) : undefined;
      if (err || !next || !nextMod) {
        await client.query('ROLLBACK');
        return fail('Conflict', err ?? 'No game fits this many players.');
      }
      const state = nextMod.init(active, Date.now(), prevState.version + 1);
      const nextParty: PartyState = { ...party, round: party.round + 1 };
      await client.query(
        `UPDATE rooms SET game_type = $2, game_state = $3, party = $4, status = 'playing' WHERE id = $1`,
        [room.id, next, JSON.stringify(state), JSON.stringify(nextParty)]
      );
      await client.query('COMMIT');
      logEvent('rematch_started', actorId, { gameType: next, party: true });
      const details = await getRoomDetailsById(room.id);
      if (details) broadcastRoomStarted(details.code, details);
      broadcastGameState(code, state);
      return { ok: true, state };
    }

    const result = opts.compute(mod, room, active, Date.now());
    if ('error' in result) { await client.query('ROLLBACK'); return fail('Conflict', result.error); }

    const justFinished = isOver(result.state) && !isOver(prevState);
    const scored = party && justFinished ? scoreRound(party, room.game_type, result.state, active) : party;
    await client.query(
      `UPDATE rooms SET game_state = $2, status = $3, party = $4 WHERE id = $1`,
      [room.id, JSON.stringify(result.state), isOver(result.state) ? 'finished' : 'playing', scored ? JSON.stringify(scored) : null]
    );
    // A game that started with 2+ players counts, even if the loser later left (they just get nothing).
    if (event !== 'game:rematch' && isOver(result.state) && (result.state.players?.length ?? 0) >= 2) {
      await awardMatchXp(client, room.id, room.game_type, result.state.version, result.state.winnerId ?? null, active);
    }
    await client.query('COMMIT');

    if (event === 'game:rematch') {
      logEvent('rematch_started', actorId, { gameType: room.game_type });
    } else if (isOver(result.state)) {
      logEvent('game_finished', actorId, {
        gameType: room.game_type,
        outcome: result.state.winnerId ? 'win' : 'draw',
        moves: result.state.version,
      });
    }
    broadcastGameState(code, result.state);
    if (party && justFinished) {
      const details = await getRoomDetailsById(room.id);
      if (details) broadcastRoomUpdated(details.code, details);
    }
    return { ok: true, state: result.state };
  } catch {
    await client.query('ROLLBACK').catch(() => {});
    return fail('Internal Server Error', 'Game action failed.');
  } finally {
    client.release();
  }
}
