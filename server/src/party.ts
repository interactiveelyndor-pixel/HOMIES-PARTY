import { randomInt } from 'crypto';
import { GAMES, GAME_IDS } from './games/registry';
import { BaseState } from './games/types';

// Party Mode: one room, several rounds, a random game each round. The server
// owns the schedule and the score; the games themselves are unchanged.

export interface PartyState {
  rounds: number;
  /** 0 until the first game starts. */
  round: number;
  scores: Record<string, number>;
  history: { round: number; gameType: string; winnerId: string | null }[];
  /** True once the last round has been scored. */
  finished: boolean;
}

export const PARTY_MIN_ROUNDS = 2;
export const PARTY_MAX_ROUNDS = 7;
export const PARTY_DEFAULT_ROUNDS = 3;
export const PARTY_MAX_PLAYERS = 4; // the largest group every multi-player game supports

export const WIN_POINTS = 3;
export const DRAW_POINTS = 2;
export const PLAY_POINTS = 1;

export function newParty(rounds: number): PartyState {
  return { rounds, round: 0, scores: {}, history: [], finished: false };
}

/** Random game that supports this many players, avoiding an immediate repeat when there is a choice. */
export function pickGame(playerCount: number, previous: string | null, pick = randomInt): string | null {
  const fits = GAME_IDS.filter((id) => GAMES[id].minPlayers <= playerCount && playerCount <= GAMES[id].maxPlayers);
  if (fits.length === 0) return null;
  const fresh = fits.filter((id) => id !== previous);
  const pool = fresh.length > 0 ? fresh : fits;
  return pool[pick(0, pool.length)];
}

/** Adds the finished round to the score. Players who left the room score nothing. */
export function scoreRound(party: PartyState, gameType: string, state: BaseState, active: string[]): PartyState {
  const scores = { ...party.scores };
  for (const id of active) {
    const gained = state.winnerId === id ? WIN_POINTS : state.winnerId ? PLAY_POINTS : DRAW_POINTS;
    scores[id] = (scores[id] ?? 0) + gained;
  }
  return {
    ...party,
    scores,
    history: [...party.history, { round: party.round, gameType, winnerId: state.winnerId ?? null }],
    finished: party.round >= party.rounds,
  };
}
