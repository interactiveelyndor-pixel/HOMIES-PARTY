// Server-authoritative Snakes & Ladders. Rules mirror lib/snl/snl_config.dart
// and lib/snl/snl_controller.dart (one roll per turn, no bonus on 6, exact roll to 100).

export const SNAKES: Record<number, number> = { 17: 7, 40: 3, 47: 26, 54: 34, 62: 19, 64: 18, 87: 24, 95: 56 };
export const LADDERS: Record<number, number> = { 4: 25, 9: 31, 20: 38, 28: 84, 36: 58, 51: 67, 63: 81, 71: 91 };

export const TURN_MS = 30_000;

export interface SnlState {
  players: { userId: string; position: number }[];
  turn: number; // index into players
  lastRoll: number | null;
  winnerId: string | null;
  version: number;
  turnDeadline: number; // epoch ms; after this anyone may report the turn as expired
}

export function initSnlState(userIds: string[], now: number, version = 0): SnlState {
  return {
    players: userIds.map((userId) => ({ userId, position: 0 })),
    turn: 0,
    lastRoll: null,
    winnerId: null,
    version,
    turnDeadline: now + TURN_MS,
  };
}

export type RollResult = { state: SnlState } | { error: string };

/** Pure: applies one roll for [userId]. [activeIds] are users still in the room. */
export function applyRoll(prev: SnlState, userId: string, roll: number, activeIds: Set<string>, now: number): RollResult {
  if (prev.winnerId) return { error: 'The game is already over.' };

  const state: SnlState = { ...prev, players: prev.players.map((p) => ({ ...p })) };

  const remaining = state.players.filter((p) => activeIds.has(p.userId));
  if (remaining.length < 2) {
    state.winnerId = remaining[0]?.userId ?? userId;
    state.version++;
    return { state };
  }

  // Skip players who left the room.
  for (let i = 0; i < state.players.length && !activeIds.has(state.players[state.turn].userId); i++) {
    state.turn = (state.turn + 1) % state.players.length;
  }
  if (state.players[state.turn].userId !== userId) return { error: 'It is not your turn.' };

  const me = state.players[state.turn];
  let target = me.position + roll;
  if (target <= 100) {
    target = SNAKES[target] ?? LADDERS[target] ?? target;
    me.position = target;
  } // overshoot: stay put
  state.lastRoll = roll;
  if (me.position === 100) state.winnerId = userId;
  else state.turn = (state.turn + 1) % state.players.length;
  state.turnDeadline = now + TURN_MS;
  state.version++;
  return { state };
}

/** Pure: passes the turn if the current player let the deadline run out. */
export function skipExpiredTurn(prev: SnlState, activeIds: Set<string>, now: number): RollResult {
  if (prev.winnerId) return { error: 'The game is already over.' };
  if (now < prev.turnDeadline) return { error: 'The turn has not expired yet.' };
  const state: SnlState = { ...prev, players: prev.players.map((p) => ({ ...p })) };
  const remaining = state.players.filter((p) => activeIds.has(p.userId));
  if (remaining.length < 2) {
    state.winnerId = remaining[0]?.userId ?? null;
  } else {
    do {
      state.turn = (state.turn + 1) % state.players.length;
    } while (!activeIds.has(state.players[state.turn].userId));
  }
  state.turnDeadline = now + TURN_MS;
  state.version++;
  return { state };
}
