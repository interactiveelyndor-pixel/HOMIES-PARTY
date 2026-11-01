// Word Rush: everyone sees the same scrambled letters and races to type the word.
// First correct guess takes the round. The word and everyone's wrong guesses stay
// on the server, so there is no player-written text to moderate.
import { randomInt } from 'crypto';
import { GameModule, GameResult } from './types';
import { RoundState, finishByScores, settleLeavers, shuffled } from './simultaneous';

export const ROUND_MS = 30_000;
export const ROUNDS = 5;
export const GUESSES_PER_ROUND = 5;
export const WIN_POINTS = 3;

// Everyday, family-friendly words. shortcut: a short built-in list; grow it (or add themes) if players repeat words too often.
export const WORDS = [
  'planet', 'garden', 'rocket', 'monkey', 'pirate', 'castle', 'pencil', 'island', 'jungle', 'dragon',
  'bridge', 'candle', 'forest', 'guitar', 'hammer', 'ladder', 'magnet', 'orange', 'parrot', 'rabbit',
  'silver', 'tunnel', 'violin', 'window', 'yellow', 'basket', 'camera', 'dinner', 'engine', 'flower',
  'galaxy', 'helmet', 'jacket', 'kitten', 'lemons', 'mirror', 'napkin', 'oyster', 'puzzle', 'ribbon',
  'saddle', 'turtle', 'umpire', 'velvet', 'winter', 'zipper', 'anchor', 'bottle', 'cookie', 'donkey',
  'eleven', 'feather', 'giraffe', 'harbor', 'iceberg', 'journey', 'kitchen', 'lantern', 'mammoth', 'network',
  'octopus', 'penguin', 'pumpkin', 'quarter', 'rainbow', 'sunrise', 'thunder', 'unicorn', 'village', 'whistle',
];

export interface WordRushState extends RoundState {
  /** The letters of this round's word, shuffled. */
  scramble: string;
  /** Guesses each player has left this round (wrong guesses are never shown). */
  guessesLeft: Record<string, number>;
  /** How the previous round ended; null before the first. */
  last: { word: string; winnerId: string | null } | null;
  _word: string;
  _used: string[];
}

const letters = (w: string) => [...w].sort().join('');

function scrambleOf(word: string): string {
  for (let i = 0; i < 20; i++) {
    const s = shuffled([...word]).join('');
    if (s !== word) return s;
  }
  return [...word].reverse().join('');
}

function startRound(state: WordRushState, now: number): void {
  const unused = WORDS.filter((w) => !state._used.includes(w));
  const word = unused[randomInt(0, unused.length)];
  state._used = [...state._used, word];
  state._word = word;
  state.scramble = scrambleOf(word);
  state.round += 1;
  state.guessesLeft = Object.fromEntries(state.players.map((p) => [p.userId, GUESSES_PER_ROUND]));
  state.turnDeadline = now + ROUND_MS;
}

/** Closes the current round and starts the next, or ends the game. */
function endRound(state: WordRushState, winnerId: string | null, now: number): void {
  state.last = { word: state._word, winnerId };
  if (winnerId) state.scores[winnerId] = (state.scores[winnerId] ?? 0) + WIN_POINTS;
  if (state.round >= state.rounds) finishByScores(state);
  else startRound(state, now);
}

function clone(s: WordRushState): WordRushState {
  return {
    ...s,
    players: s.players.map((p) => ({ ...p })),
    scores: { ...s.scores },
    guessesLeft: { ...s.guessesLeft },
    last: s.last ? { ...s.last } : null,
    _used: [...s._used],
  };
}

const over = (s: WordRushState) => s.winnerId !== null || s.draw === true;

export const wordrush: GameModule<WordRushState> = {
  id: 'wordrush',
  minPlayers: 2,
  maxPlayers: 4,

  init(userIds, now, version = 0) {
    const state: WordRushState = {
      players: userIds.map((userId) => ({ userId })),
      turn: 0,
      winnerId: null,
      draw: false,
      version,
      turnDeadline: now,
      simultaneous: true,
      round: 0,
      rounds: ROUNDS,
      scores: Object.fromEntries(userIds.map((u) => [u, 0])),
      scramble: '',
      guessesLeft: {},
      last: null,
      _word: '',
      _used: [],
    };
    startRound(state, now);
    return state;
  },

  move(prev, userId, input, ctx): GameResult<WordRushState> {
    if (over(prev)) return { error: 'The game is already over.' };
    if (!prev.players.some((p) => p.userId === userId)) return { error: 'You are not in this game.' };
    const raw = (input as { guess?: unknown } | null)?.guess;
    if (typeof raw !== 'string') return { error: 'Type your guess.' };
    const guess = raw.trim().toLowerCase();
    if (!/^[a-z]{2,12}$/.test(guess)) return { error: 'Use letters only.' };

    const state = clone(prev);
    if (settleLeavers(state, ctx.active)) {
      state.version++;
      return { state };
    }
    if ((state.guessesLeft[userId] ?? 0) <= 0) return { error: 'No guesses left this round.' };
    state.guessesLeft[userId]--;

    // The answer, or another real word made of the same letters.
    const correct = guess === state._word || (WORDS.includes(guess) && letters(guess) === letters(state._word));
    if (correct) endRound(state, userId, ctx.now);
    state.version++;
    return { state };
  },

  skip(prev, active, now): GameResult<WordRushState> {
    if (over(prev)) return { error: 'The game is already over.' };
    if (now < prev.turnDeadline) return { error: 'The round has not expired yet.' };
    const state = clone(prev);
    if (!settleLeavers(state, active)) endRound(state, null, now);
    state.version++;
    return { state };
  },
};
