import assert from 'node:assert/strict';
import { wordrush, WORDS, ROUNDS as WR_ROUNDS, GUESSES_PER_ROUND } from '../src/games/wordrush';
import { bluff, QUESTIONS, norm, clean, WRITE_MS, VOTE_MS, REVEAL_MS } from '../src/games/bluff';
import { publicState } from '../src/games/types';
import { GAMES } from '../src/games/registry';

const A = 'a', B = 'b', C = 'c';
const ctx = (now: number, who: string[] = [A, B, C]) => ({ active: new Set(who), now, randomInt: (lo: number) => lo });
const ok = <S>(r: { state: S } | { error: string }): S => {
  assert.ok('state' in r, 'error' in r ? r.error : '');
  return r.state;
};

// ---- word list sanity
assert.equal(new Set(WORDS).size, WORDS.length, 'no duplicate words');
for (const w of WORDS) assert.match(w, /^[a-z]{6,7}$/);
console.log('PASS: word list');

// ---- Word Rush
{
  let s = wordrush.init([A, B], 1000, 0);
  assert.equal(s.round, 1);
  assert.equal([...s.scramble].sort().join(''), [...s._word].sort().join(''));
  assert.notEqual(s.scramble, s._word);
  assert.equal(s.guessesLeft[A], GUESSES_PER_ROUND);
  assert.ok(!('_word' in publicState(s)) && !('_used' in publicState(s)), 'secrets are hidden');
  assert.equal(publicState(s).scramble, s.scramble);

  assert.ok('error' in wordrush.move(s, A, { guess: 'abc!' }, ctx(1100, [A, B])), 'letters only');
  assert.ok('error' in wordrush.move(s, A, { guess: 5 }, ctx(1100, [A, B])), 'must be text');
  assert.ok('error' in wordrush.move(s, 'zed', { guess: 'planet' }, ctx(1100, [A, B])), 'outsiders cannot play');

  // wrong guess costs a guess but changes nothing else
  const wrong = ok(wordrush.move(s, A, { guess: 'qqqqqq' }, ctx(1100, [A, B])));
  assert.equal(wrong.guessesLeft[A], GUESSES_PER_ROUND - 1);
  assert.equal(wrong.round, 1);
  assert.equal(wrong.version, s.version + 1);
  // guesses run out
  let t = s;
  for (let i = 0; i < GUESSES_PER_ROUND; i++) t = ok(wordrush.move(t, A, { guess: 'qqqqqq' }, ctx(1100, [A, B])));
  assert.ok('error' in wordrush.move(t, A, { guess: s._word }, ctx(1100, [A, B])), 'out of guesses');
  assert.ok(!('error' in wordrush.move(t, B, { guess: s._word }, ctx(1100, [A, B]))), 'others still can');

  // the first correct guess wins the round (case and spaces ignored) and a new word starts
  const first = s._word;
  s = ok(wordrush.move(s, B, { guess: `  ${first.toUpperCase()} ` }, ctx(1200, [A, B])));
  assert.equal(s.scores[B], 3);
  assert.equal(s.last?.winnerId, B);
  assert.equal(s.last?.word, first);
  assert.equal(s.round, 2);
  assert.notEqual(s._word, first);

  // nobody solves it: skip only after the deadline, no points
  assert.ok('error' in wordrush.skip(s, new Set([A, B]), s.turnDeadline - 1));
  s = ok(wordrush.skip(s, new Set([A, B]), s.turnDeadline));
  assert.equal(s.last?.winnerId, null);
  assert.equal(s.round, 3);

  // play to the end: B wins every round it can
  while (s.winnerId === null && !s.draw) {
    s = ok(wordrush.move(s, B, { guess: s._word }, ctx(s.turnDeadline - 5, [A, B])));
  }
  assert.equal(s.round, WR_ROUNDS);
  assert.equal(s.winnerId, B);
  assert.ok(s.scores[B] > s.scores[A]);
  assert.ok('error' in wordrush.move(s, A, { guess: 'planet' }, ctx(9e9, [A, B])), 'finished');

  // a tie is a draw
  let d = wordrush.init([A, B], 0, 0);
  while (d.winnerId === null && !d.draw) d = ok(wordrush.skip(d, new Set([A, B]), d.turnDeadline));
  assert.equal(d.draw, true);

  // a leaver ends it for the other player
  const l = ok(wordrush.skip(wordrush.init([A, B], 0), new Set([A]), 30_000));
  assert.equal(l.winnerId, A);
  console.log('PASS: Word Rush rules');
}

// ---- Bluff & Vote
{
  assert.ok(GAMES.bluff.privateOnly, 'Bluff is private-room only');
  assert.equal(norm('The Volga!'), 'volga');
  assert.equal(norm('  a   MURDER '), 'murder');
  assert.equal(clean('  hi\u0000 there\n'), 'hi there');
  for (const q of QUESTIONS) assert.ok(q.q.length > 10 && q.a.length > 0);

  let s = bluff.init([A, B, C], 0, 0);
  const truth = s._truth;
  assert.equal(s.phase, 'write');
  assert.ok(!('_truth' in publicState(s)) && !('_fakes' in publicState(s)));

  assert.ok('error' in bluff.move(s, A, { answer: truth }, ctx(10)), 'cannot submit the truth');
  assert.ok('error' in bluff.move(s, A, { answer: `THE ${norm(truth)}!` }, ctx(10)), 'the truth with different case/article/punctuation is still the truth');
  assert.ok('error' in bluff.move(s, A, { answer: '' }, ctx(10)));
  assert.ok('error' in bluff.move(s, A, { answer: 'x'.repeat(31) }, ctx(10)));
  assert.ok('error' in bluff.move(s, A, { answer: '!!!' }, ctx(10)), 'needs letters or numbers');
  assert.ok('error' in bluff.move(s, A, { vote: 1 }, ctx(10)));
  assert.ok('error' in bluff.move(s, 'zed', { answer: 'Fake' }, ctx(10)));

  s = ok(bluff.move(s, A, { answer: 'Fake One' }, ctx(10)));
  assert.deepEqual(s.submitted, [A]);
  assert.ok(!JSON.stringify(publicState(s)).includes('Fake One'), 'fakes stay hidden while writing');
  assert.ok('error' in bluff.move(s, A, { answer: 'Again' }, ctx(11)), 'one answer each');
  assert.ok('error' in bluff.move(s, B, { answer: 'fake one' }, ctx(11)), 'no duplicate fakes');
  s = ok(bluff.move(s, B, { answer: 'Fake Two' }, ctx(12)));
  assert.equal(s.phase, 'write');
  s = ok(bluff.move(s, C, { answer: 'Fake Three' }, ctx(13)));
  assert.equal(s.phase, 'vote', 'everyone wrote, so voting starts');
  assert.equal(s.options!.length, 4);
  assert.deepEqual(s.options!.map((o) => o.text).sort(), [truth, 'Fake One', 'Fake Two', 'Fake Three'].sort());
  assert.ok(!('authors' in s.options![0]), 'authors are hidden during voting');
  assert.equal(s.turnDeadline, 13 + VOTE_MS);

  const idOf = (text: string) => s.options!.find((o) => o.text === text)!.id;
  assert.ok('error' in bluff.move(s, A, { option: idOf('Fake One') }, ctx(14)), 'not your own fake');
  assert.ok('error' in bluff.move(s, A, { option: 99 }, ctx(14)));
  assert.ok('error' in bluff.move(s, A, { option: 1.5 }, ctx(14)));
  s = ok(bluff.move(s, A, { option: idOf(truth) }, ctx(14)));       // A finds the truth: +2
  assert.ok('error' in bluff.move(s, A, { option: idOf('Fake Two') }, ctx(15)), 'one vote each');
  s = ok(bluff.move(s, B, { option: idOf('Fake Three') }, ctx(15))); // B fooled by C: C +1
  assert.equal(s.phase, 'vote');
  s = ok(bluff.move(s, C, { option: idOf('Fake Two') }, ctx(16)));   // C fooled by B: B +1
  assert.equal(s.phase, 'reveal');
  assert.deepEqual(s.reveal!.gained, { [A]: 2, [B]: 1, [C]: 1 });
  assert.deepEqual(s.scores, { [A]: 2, [B]: 1, [C]: 1 });
  assert.equal(s.options![s.reveal!.truthId].text, truth);
  assert.deepEqual(s.reveal!.authors[idOf('Fake Two')], [B]);
  assert.deepEqual(s.reveal!.votes[idOf('Fake Two')], [C]);
  assert.ok(!('_votes' in publicState(s)));
  assert.equal(s.turnDeadline, 16 + REVEAL_MS);

  // reveal moves on by the clock; three questions then the game ends
  assert.ok('error' in bluff.skip(s, new Set([A, B, C]), s.turnDeadline - 1));
  s = ok(bluff.skip(s, new Set([A, B, C]), s.turnDeadline));
  assert.equal(s.round, 2);
  assert.equal(s.phase, 'write');
  assert.notEqual(s._truth, truth, 'a different question');

  // nobody writes anything: straight to a reveal with no points, then on
  s = ok(bluff.skip(s, new Set([A, B, C]), s.turnDeadline));
  assert.equal(s.phase, 'reveal');
  assert.deepEqual(s.reveal!.gained, { [A]: 0, [B]: 0, [C]: 0 });
  s = ok(bluff.skip(s, new Set([A, B, C]), s.turnDeadline));
  assert.equal(s.round, 3);
  // round 3: only A writes; B and C must not be able to vote for A's... they can; skip the vote phase
  s = ok(bluff.move(s, A, { answer: 'Lone Fake' }, ctx(0)));
  s = ok(bluff.skip(s, new Set([A, B, C]), s.turnDeadline)); // vote phase
  assert.equal(s.phase, 'vote');
  s = ok(bluff.skip(s, new Set([A, B, C]), s.turnDeadline)); // nobody voted
  assert.equal(s.phase, 'reveal');
  s = ok(bluff.skip(s, new Set([A, B, C]), s.turnDeadline));
  assert.equal(s.winnerId, A, 'A leads 2-1-1');
  assert.ok('error' in bluff.move(s, A, { answer: 'late' }, ctx(0)));

  // leavers: two players leaving ends it for the one left
  const l = ok(bluff.skip(bluff.init([A, B, C], 0), new Set([C]), WRITE_MS));
  assert.equal(l.winnerId, C);
  console.log('PASS: Bluff & Vote rules');
}
