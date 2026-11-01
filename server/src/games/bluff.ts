// Bluff & Vote: a trivia question with one true answer. Everyone writes a fake
// answer, then everyone votes for the one they think is true. Voting for the
// truth earns 2; each vote your fake receives earns 1.
//
// Players type short text that other players see, so this game is for private
// rooms only (a room code is needed to join) and reveal screens carry a report
// button. Nothing is stored beyond the room's game state.
import { randomInt } from 'crypto';
import { GameModule, GameResult } from './types';
import { RoundState, finishByScores, settleLeavers, shuffled } from './simultaneous';

export const WRITE_MS = 45_000;
export const VOTE_MS = 30_000;
export const REVEAL_MS = 10_000;
export const ROUNDS = 3;
export const TRUTH_POINTS = 2;
export const FOOL_POINTS = 1;
export const MAX_ANSWER_LENGTH = 30;

// Questions with one short, well-known true answer. shortcut: a small built-in list; add more before launch to avoid repeats.
export const QUESTIONS: { q: string; a: string }[] = [
  { q: 'What is the only mammal that can truly fly?', a: 'A bat' },
  { q: 'What is the capital city of Australia?', a: 'Canberra' },
  { q: 'What is a group of crows called?', a: 'A murder' },
  { q: 'What is a group of flamingos called?', a: 'A flamboyance' },
  { q: 'How many hearts does an octopus have?', a: 'Three' },
  { q: 'What is the chemical symbol for gold?', a: 'Au' },
  { q: 'What is the longest river in Europe?', a: 'The Volga' },
  { q: 'What do you call a baby kangaroo?', a: 'A joey' },
  { q: 'Which city hosted the first modern Olympic Games in 1896?', a: 'Athens' },
  { q: 'What is the national animal of Scotland?', a: 'The unicorn' },
  { q: 'What colour is a polar bear\'s skin?', a: 'Black' },
  { q: 'What is the smallest bone in the human body?', a: 'The stapes' },
  { q: 'In which year did the Titanic sink?', a: '1912' },
  { q: 'Which planet in our solar system has the shortest day?', a: 'Jupiter' },
];

export interface BluffOption {
  id: number;
  text: string;
}

export interface BluffReveal {
  /** Which option was the real answer. */
  truthId: number;
  /** Who wrote each fake, by option id. Empty for the real answer. */
  authors: Record<number, string[]>;
  /** Who voted for each option. */
  votes: Record<number, string[]>;
  /** Points each player earned this round. */
  gained: Record<string, number>;
}

export interface BluffState extends RoundState {
  phase: 'write' | 'vote' | 'reveal';
  question: string;
  /** Who has already written / voted (never what). */
  submitted: string[];
  voted: string[];
  /** Shuffled answers, shown from the voting phase on, with no authors. */
  options: BluffOption[] | null;
  reveal: BluffReveal | null;
  _truth: string;
  _fakes: Record<string, string>;
  _optionAuthors: Record<number, string[]>;
  _truthId: number;
  _votes: Record<string, number>;
  _used: number[];
}

/** For comparing answers: case, spacing, punctuation and a leading article do not matter. */
export const norm = (t: string) =>
  t.toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim().replace(/^(a|an|the) /, '');

/** Trims, collapses spaces and drops control characters. */
export const clean = (t: string) => t.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();

function startQuestion(state: BluffState, now: number): void {
  const unused = QUESTIONS.map((_, i) => i).filter((i) => !state._used.includes(i));
  const pick = unused[randomInt(0, unused.length)];
  state._used = [...state._used, pick];
  state.round += 1;
  state.phase = 'write';
  state.question = QUESTIONS[pick].q;
  state._truth = QUESTIONS[pick].a;
  state._fakes = {};
  state._votes = {};
  state._optionAuthors = {};
  state.submitted = [];
  state.voted = [];
  state.options = null;
  state.reveal = null;
  state.turnDeadline = now + WRITE_MS;
}

function toReveal(state: BluffState, now: number): void {
  const authors: Record<number, string[]> = {};
  const votes: Record<number, string[]> = {};
  const gained: Record<string, number> = Object.fromEntries(state.players.map((p) => [p.userId, 0]));
  for (const o of state.options ?? []) {
    authors[o.id] = state._optionAuthors[o.id] ?? [];
    votes[o.id] = [];
  }
  for (const [voter, choice] of Object.entries(state._votes)) {
    votes[choice]?.push(voter);
    if (choice === state._truthId) gained[voter] += TRUTH_POINTS;
    else for (const author of state._optionAuthors[choice] ?? []) gained[author] += FOOL_POINTS;
  }
  for (const [id, pts] of Object.entries(gained)) state.scores[id] = (state.scores[id] ?? 0) + pts;
  state.reveal = { truthId: state._truthId, authors, votes, gained };
  state.phase = 'reveal';
  state.turnDeadline = now + REVEAL_MS;
}

function toVote(state: BluffState, now: number): void {
  const entries: { text: string; authors: string[] }[] = [{ text: state._truth, authors: [] }];
  for (const [userId, text] of Object.entries(state._fakes)) entries.push({ text, authors: [userId] });
  const order = shuffled(entries.map((_, i) => i));
  state.options = order.map((entryIndex, id) => ({ id, text: entries[entryIndex].text }));
  state._truthId = order.indexOf(0);
  state._optionAuthors = Object.fromEntries(order.map((entryIndex, id) => [id, entries[entryIndex].authors]));
  state.phase = 'vote';
  state.turnDeadline = now + VOTE_MS;
  // Nobody wrote a fake: there is nothing to choose between.
  if (entries.length < 2) toReveal(state, now);
}

/** Moves on when the current phase has run its course. */
function advance(state: BluffState, now: number): void {
  if (state.phase === 'write') toVote(state, now);
  else if (state.phase === 'vote') toReveal(state, now);
  else if (state.round >= state.rounds) finishByScores(state);
  else startQuestion(state, now);
}

function clone(s: BluffState): BluffState {
  return {
    ...s,
    players: s.players.map((p) => ({ ...p })),
    scores: { ...s.scores },
    submitted: [...s.submitted],
    voted: [...s.voted],
    options: s.options ? s.options.map((o) => ({ ...o })) : null,
    reveal: s.reveal,
    _fakes: { ...s._fakes },
    _optionAuthors: { ...s._optionAuthors },
    _votes: { ...s._votes },
    _used: [...s._used],
  };
}

const over = (s: BluffState) => s.winnerId !== null || s.draw === true;

export const bluff: GameModule<BluffState> = {
  id: 'bluff',
  minPlayers: 3,
  maxPlayers: 4,
  privateOnly: true,

  init(userIds, now, version = 0) {
    const state: BluffState = {
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
      phase: 'write',
      question: '',
      submitted: [],
      voted: [],
      options: null,
      reveal: null,
      _truth: '',
      _fakes: {},
      _optionAuthors: {},
      _truthId: 0,
      _votes: {},
      _used: [],
    };
    startQuestion(state, now);
    return state;
  },

  move(prev, userId, input, ctx): GameResult<BluffState> {
    if (over(prev)) return { error: 'The game is already over.' };
    if (!prev.players.some((p) => p.userId === userId)) return { error: 'You are not in this game.' };
    const state = clone(prev);
    if (settleLeavers(state, ctx.active)) {
      state.version++;
      return { state };
    }
    const activeIds = state.players.map((p) => p.userId).filter((id) => ctx.active.has(id));

    if (state.phase === 'write') {
      const raw = (input as { answer?: unknown } | null)?.answer;
      if (typeof raw !== 'string') return { error: 'Write your answer.' };
      const answer = clean(raw);
      if (answer.length < 1 || answer.length > MAX_ANSWER_LENGTH) {
        return { error: `Answers are 1-${MAX_ANSWER_LENGTH} characters.` };
      }
      if (state._fakes[userId] !== undefined) return { error: 'You already wrote an answer.' };
      const key = norm(answer);
      if (key === '') return { error: 'Use letters or numbers.' };
      if (key === norm(state._truth)) return { error: 'Try a different answer.' };
      if (Object.values(state._fakes).some((f) => norm(f) === key)) {
        return { error: 'Someone already wrote that. Try another.' };
      }
      state._fakes[userId] = answer;
      state.submitted.push(userId);
      if (activeIds.every((id) => state._fakes[id] !== undefined)) advance(state, ctx.now);
    } else if (state.phase === 'vote') {
      const option = (input as { option?: unknown } | null)?.option;
      if (typeof option !== 'number' || !Number.isInteger(option) || !state.options?.some((o) => o.id === option)) {
        return { error: 'Pick one of the answers.' };
      }
      if (state._votes[userId] !== undefined) return { error: 'You already voted.' };
      if (state._optionAuthors[option]?.includes(userId)) return { error: 'You cannot vote for your own answer.' };
      state._votes[userId] = option;
      state.voted.push(userId);
      if (activeIds.every((id) => state._votes[id] !== undefined)) advance(state, ctx.now);
    } else {
      return { error: 'Wait for the next question.' };
    }
    state.version++;
    return { state };
  },

  skip(prev, active, now): GameResult<BluffState> {
    if (over(prev)) return { error: 'The game is already over.' };
    if (now < prev.turnDeadline) return { error: 'The phase has not expired yet.' };
    const state = clone(prev);
    if (!settleLeavers(state, active)) advance(state, now);
    state.version++;
    return { state };
  },
};
