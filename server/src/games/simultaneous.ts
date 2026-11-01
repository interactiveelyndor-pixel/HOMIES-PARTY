// Shared by games where everyone acts at once (no turn order). Such games set
// `simultaneous: true` so clients do not wait for "your turn".
import { randomInt } from 'crypto';
import { BaseState } from './types';

export interface RoundState extends BaseState {
  simultaneous: true;
  round: number;
  rounds: number;
  scores: Record<string, number>;
}

export function shuffled<T>(items: T[]): T[] {
  const a = [...items];
  for (let i = a.length - 1; i > 0; i--) {
    const j = randomInt(0, i + 1);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Ends the game by score: the single highest scorer wins, otherwise it is a draw. */
export function finishByScores(state: RoundState): void {
  const entries = state.players.map((p) => [p.userId, state.scores[p.userId] ?? 0] as const);
  const top = Math.max(...entries.map((e) => e[1]));
  const leaders = entries.filter((e) => e[1] === top);
  state.winnerId = leaders.length === 1 ? leaders[0][0] : null;
  state.draw = leaders.length !== 1;
}

/** If fewer than two players remain, the game ends and the one left (if any) wins. Returns true if it ended. */
export function settleLeavers(state: RoundState, active: Set<string>): boolean {
  const remaining = state.players.filter((p) => active.has(p.userId));
  if (remaining.length >= 2) return false;
  state.winnerId = remaining[0]?.userId ?? null;
  state.draw = remaining.length === 0;
  return true;
}
