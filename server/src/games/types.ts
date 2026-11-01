// A server-authoritative turn-based game. The server owns the state, validates
// every move and picks any randomness; clients only send inputs and render.
// To add a game: implement GameModule and add it to GAMES in registry.ts.

export interface BaseState {
  players: { userId: string }[];
  turn: number; // index into players
  winnerId: string | null;
  draw?: boolean;
  version: number; // increases on every change so clients can drop stale updates
  turnDeadline: number; // epoch ms; after this anyone may report the turn as expired
}

export type GameResult<S> = { state: S } | { error: string };

export interface MoveContext {
  /** Users still in the room (players who left are skipped). */
  active: Set<string>;
  now: number;
  randomInt(minInclusive: number, maxExclusive: number): number;
}

export interface GameModule<S extends BaseState = BaseState> {
  id: string;
  minPlayers: number;
  maxPlayers: number;
  /** Players write text others see, so it is only offered in rooms joined by code, never by Quick Match. */
  privateOnly?: boolean;
  init(userIds: string[], now: number, version?: number): S;
  /** `input` comes from the client and must be validated here. */
  move(state: S, userId: string, input: unknown, ctx: MoveContext): GameResult<S>;
  /** Pass the turn when the current player let the deadline run out. */
  skip(state: S, active: Set<string>, now: number): GameResult<S>;
}

export const isOver = (s: BaseState): boolean => s.winnerId !== null || s.draw === true;

/**
 * What clients may see. Keys starting with "_" hold the server's secrets (the
 * word to guess, the real answer, who wrote what) and never leave the server;
 * a game publishes them in a normal field when they should be revealed.
 */
export function publicState<T>(state: T): T {
  if (!state || typeof state !== 'object' || Array.isArray(state)) return state;
  return Object.fromEntries(Object.entries(state).filter(([k]) => !k.startsWith('_'))) as T;
}
