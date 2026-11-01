// Ludo rules, ported from lib/logic/ludo_controller.dart and lib/models/board_path.dart.
// A parity test replays games recorded from the Dart controller (see
// scripts/test-ludo.ts), so the two stay in step.
//
// Token steps: -1 = in base, 0..50 = common track, 51..55 = home stretch, 56 = home.
// Colours: 0 red, 1 green, 2 yellow, 3 blue (same order as PlayerColor in Dart).
import { BaseState, GameModule, GameResult, MoveContext } from './types';

export const BASE = -1;
export const HOME = 56;
export const TURN_MS = 30_000;

const COLOR_SETS: Record<number, number[]> = { 2: [0, 2], 3: [0, 1, 2], 4: [0, 1, 2, 3] };
/** Common-track indices that cannot be captured: the 4 start cells and the 4 stars. */
const SAFE_TRACK = new Set([0, 13, 26, 39, 8, 21, 34, 47]);

export interface LudoPlayer {
  userId: string;
  color: number;
  tokens: number[]; // 4 step counts
}

export interface LudoState extends BaseState {
  players: LudoPlayer[];
  phase: 'roll' | 'move';
  dice: number | null; // the roll waiting for a token choice
  movable: number[]; // token ids that may move (phase 'move')
  consecutiveSixes: number;
  lastRoll: number | null;
  /** Index of the player who made the last action (it may no longer be their turn). */
  lastActor: number;
  /** What the last action did: none, six, capture, home, noMove, forfeit, win. */
  lastEvent: string;
}

const trackIndex = (color: number, step: number) => (color * 13 + step) % 52;
const onCommonTrack = (step: number) => step >= 0 && step <= 50;

function clone(s: LudoState): LudoState {
  return {
    ...s,
    players: s.players.map((p) => ({ ...p, tokens: [...p.tokens] })),
    movable: [...s.movable],
  };
}

export function legalMoves(tokens: number[], dice: number): number[] {
  const out: number[] = [];
  tokens.forEach((step, id) => {
    if (step === HOME) return;
    if (step === BASE) {
      if (dice === 6) out.push(id);
    } else if (step + dice <= HOME) {
      out.push(id);
    }
  });
  return out;
}

/** Next player (after the current one) who is still in the room. */
function advance(state: LudoState, active: Set<string>): void {
  let next = state.turn;
  for (let i = 0; i < state.players.length; i++) {
    next = (next + 1) % state.players.length;
    if (active.has(state.players[next].userId)) break;
  }
  state.turn = next;
  state.phase = 'roll';
  state.dice = null;
  state.movable = [];
  state.consecutiveSixes = 0;
}

/** Fewer than two players left: the last one wins. Otherwise skip leavers' turns. */
function settleLeavers(state: LudoState, active: Set<string>): void {
  const remaining = state.players.filter((p) => active.has(p.userId));
  if (remaining.length < 2) {
    state.winnerId = remaining[0]?.userId ?? null;
    state.draw = remaining.length === 0;
    state.lastEvent = 'win';
    return;
  }
  if (!active.has(state.players[state.turn].userId)) {
    advance(state, active); // moves to the next player still here
  }
}

/** Moves one token by `dice` and resolves captures, home, bonus turns and victory. */
function moveToken(state: LudoState, tokenId: number, dice: number, active: Set<string>): void {
  const me = state.players[state.turn];
  const before = me.tokens[tokenId];
  me.tokens[tokenId] = before === BASE ? 0 : before + dice;
  const step = me.tokens[tokenId];

  let bonus = false;
  let event = 'none';

  if (step === HOME) {
    if (me.tokens.every((t) => t === HOME)) {
      state.winnerId = me.userId;
      state.phase = 'roll';
      state.dice = null;
      state.movable = [];
      state.lastEvent = 'win';
      return;
    }
    bonus = true;
    event = 'home';
  }

  // Captures: only on the common track, never on a safe cell or the home stretch.
  if (onCommonTrack(step)) {
    const here = trackIndex(me.color, step);
    if (!SAFE_TRACK.has(here)) {
      let captured = false;
      for (const other of state.players) {
        if (other === me) continue;
        other.tokens = other.tokens.map((t) => {
          if (onCommonTrack(t) && trackIndex(other.color, t) === here) {
            captured = true;
            return BASE;
          }
          return t;
        });
      }
      if (captured) {
        bonus = true;
        event = 'capture';
      }
    }
  }

  if (dice === 6) {
    bonus = true;
    if (event === 'none') event = 'six';
  }

  state.lastEvent = event;
  if (bonus) {
    state.phase = 'roll';
    state.dice = null;
    state.movable = [];
  } else {
    advance(state, active);
  }
}

function startOfTurn(state: LudoState, now: number): void {
  state.turnDeadline = now + TURN_MS;
  state.version++;
}

export const ludo: GameModule<LudoState> = {
  id: 'ludo',
  minPlayers: 2,
  maxPlayers: 4,

  init(userIds, now, version = 0): LudoState {
    const colors = COLOR_SETS[userIds.length];
    if (!colors) throw new Error('Ludo needs 2 to 4 players.');
    return {
      players: userIds.map((userId, i) => ({ userId, color: colors[i], tokens: [BASE, BASE, BASE, BASE] })),
      turn: 0,
      phase: 'roll',
      dice: null,
      movable: [],
      consecutiveSixes: 0,
      lastRoll: null,
      lastActor: 0,
      lastEvent: 'none',
      winnerId: null,
      draw: false,
      version,
      turnDeadline: now + TURN_MS,
    };
  },

  /**
   * No input = roll the dice (the server's own roll). `{ token: id }` = move that
   * token after a roll. Anything else is rejected, so a stale client cannot roll
   * when it meant to move, or the other way round.
   */
  move(prev, userId, input, ctx: MoveContext): GameResult<LudoState> {
    if (prev.winnerId || prev.draw) return { error: 'The game is already over.' };
    const state = clone(prev);
    settleLeavers(state, ctx.active);
    if (state.winnerId || state.draw) {
      startOfTurn(state, ctx.now);
      return { state };
    }
    if (state.players[state.turn].userId !== userId) return { error: 'It is not your turn.' };

    const me = state.players[state.turn];
    state.lastActor = state.turn;
    const wantsMove = input !== undefined && input !== null;

    if (!wantsMove) {
      if (state.phase !== 'roll') return { error: 'Choose a token to move.' };
      const roll = ctx.randomInt(1, 7);
      state.lastRoll = roll;
      state.consecutiveSixes = roll === 6 ? state.consecutiveSixes + 1 : 0;

      if (state.consecutiveSixes >= 3) {
        state.lastEvent = 'forfeit';
        advance(state, ctx.active);
        startOfTurn(state, ctx.now);
        return { state };
      }
      const legal = legalMoves(me.tokens, roll);
      if (legal.length === 0) {
        state.lastEvent = 'noMove';
        advance(state, ctx.active);
        startOfTurn(state, ctx.now);
        return { state };
      }
      if (legal.length === 1) {
        // Only one choice: play it for the player.
        moveToken(state, legal[0], roll, ctx.active);
      } else {
        state.phase = 'move';
        state.dice = roll;
        state.movable = legal;
        state.lastEvent = 'none';
      }
      startOfTurn(state, ctx.now);
      return { state };
    }

    const token = (input as { token?: unknown }).token;
    if (typeof token !== 'number' || !Number.isInteger(token)) return { error: 'Choose one of your tokens.' };
    if (state.phase !== 'move' || state.dice === null) return { error: 'Roll the dice first.' };
    if (!state.movable.includes(token)) return { error: 'That token cannot move.' };
    moveToken(state, token, state.dice, ctx.active);
    startOfTurn(state, ctx.now);
    return { state };
  },

  /** The current player ran out of time: play a sensible move for them, or pass. */
  skip(prev, active, now): GameResult<LudoState> {
    if (prev.winnerId || prev.draw) return { error: 'The game is already over.' };
    if (now < prev.turnDeadline) return { error: 'The turn has not expired yet.' };
    const state = clone(prev);
    settleLeavers(state, active);
    if (!state.winnerId && !state.draw) {
      state.lastActor = state.turn;
      if (state.phase === 'move' && state.dice !== null && state.movable.length > 0) {
        const me = state.players[state.turn];
        // Furthest-advanced token that can move.
        const best = [...state.movable].sort((a, b) => me.tokens[b] - me.tokens[a])[0];
        moveToken(state, best, state.dice, active);
      } else {
        state.lastEvent = 'noMove';
        advance(state, active);
      }
    }
    startOfTurn(state, now);
    return { state };
  },
};
