import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { ludo, legalMoves, LudoState, BASE, HOME, TURN_MS } from '../src/games/ludo';

const T0 = 1_000_000;
const users = (n: number) => Array.from({ length: n }, (_, i) => `u${i}`);
const everyone = (n: number) => new Set(users(n));
const rig = (rolls: number[], active = everyone(4), now = T0) => ({
  active,
  now,
  randomInt: () => {
    if (!rolls.length) throw new Error('ran out of scripted rolls');
    return rolls.shift()!;
  },
});
const ok = (r: any): LudoState => { assert.ok(!('error' in r), r.error); return r.state; };
const err = (r: any): string => { assert.ok('error' in r, 'expected an error'); return r.error; };
const fresh = (n = 4): LudoState => ludo.init(users(n), T0);
const withTokens = (s: LudoState, tokens: number[][], turn = 0): LudoState => {
  const c = structuredClone(s);
  tokens.forEach((t, i) => (c.players[i].tokens = t));
  c.turn = turn;
  return c;
};
const roll = (s: LudoState, rolls: number[], n = 4) => ludo.move(s, `u${s.turn}`, undefined, rig(rolls, everyone(n)));
const pick = (s: LudoState, token: number, n = 4) => ludo.move(s, `u${s.turn}`, { token }, rig([], everyone(n)));

// ---------- setup
assert.deepEqual(ludo.init(users(2), T0).players.map((p) => p.color), [0, 2]);
assert.deepEqual(ludo.init(users(3), T0).players.map((p) => p.color), [0, 1, 2]);
assert.deepEqual(ludo.init(users(4), T0).players.map((p) => p.color), [0, 1, 2, 3]);
assert.throws(() => ludo.init(users(1), T0));
assert.throws(() => ludo.init(users(5), T0));
let s = fresh();
assert.ok(s.players.every((p) => p.tokens.every((t) => t === BASE)));
assert.equal(s.turnDeadline, T0 + TURN_MS);
assert.equal(ludo.init(users(2), T0, 7).version, 7);

// ---------- legal moves
assert.deepEqual(legalMoves([BASE, BASE, BASE, BASE], 5), []);
assert.deepEqual(legalMoves([BASE, 3, HOME, 54], 6), [0, 1]);
assert.deepEqual(legalMoves([BASE, 3, HOME, 54], 2), [1, 3]);
assert.deepEqual(legalMoves([55, 55, 55, 55], 2), []);

// ---------- leaving base needs a six
s = ok(roll(fresh(), [3]));
assert.equal(s.lastEvent, 'noMove');
assert.equal(s.turn, 1, 'turn passes when nothing can move');
assert.equal(s.lastRoll, 3);

s = ok(roll(fresh(), [6]));
assert.equal(s.phase, 'move');
assert.deepEqual(s.movable, [0, 1, 2, 3]);
assert.equal(s.dice, 6);
s = ok(pick(s, 2));
assert.equal(s.players[0].tokens[2], 0);
assert.equal(s.turn, 0, 'a six gives another roll');
assert.equal(s.phase, 'roll');
assert.equal(s.lastEvent, 'six');

// ---------- three sixes in a row forfeit the turn
{
  let c = withTokens(fresh(), [[10, BASE, BASE, BASE]]);
  c.consecutiveSixes = 2;
  c = ok(roll(c, [6]));
  assert.equal(c.lastEvent, 'forfeit');
  assert.equal(c.turn, 1);
  assert.equal(c.consecutiveSixes, 0);
  assert.equal(c.players[0].tokens[0], 10, 'nothing moved');
}

// ---------- one legal token is played automatically; two wait for a choice
{
  const c = ok(roll(withTokens(fresh(), [[10, BASE, BASE, BASE]]), [4]));
  assert.equal(c.players[0].tokens[0], 14);
  assert.equal(c.turn, 1);
  const two = ok(roll(withTokens(fresh(), [[10, 20, BASE, BASE]]), [4]));
  assert.equal(two.phase, 'move');
  assert.deepEqual(two.movable, [0, 1]);
  assert.equal(two.turn, 0, 'still the same player, waiting for a token');
}

// ---------- home needs the exact number
{
  const home = ok(roll(withTokens(fresh(), [[52, BASE, BASE, BASE]]), [4]));
  assert.equal(home.players[0].tokens[0], HOME);
  assert.equal(home.lastEvent, 'home');
  assert.equal(home.turn, 0, 'reaching home earns a bonus roll');
  const over = ok(roll(withTokens(fresh(), [[54, BASE, BASE, BASE]]), [4]));
  assert.equal(over.players[0].tokens[0], 54);
  assert.equal(over.lastEvent, 'noMove');
  assert.equal(over.turn, 1);
}

// ---------- captures
{
  // red token 3 -> 5 lands on track cell 5; green token at step 44 is on cell (13+44)%52 = 5
  const c = withTokens(fresh(), [[3, BASE, BASE, BASE], [44, BASE, BASE, BASE]]);
  const r = ok(roll(c, [2]));
  assert.equal(r.players[0].tokens[0], 5);
  assert.equal(r.players[1].tokens[0], BASE, 'the opponent goes back to base');
  assert.equal(r.lastEvent, 'capture');
  assert.equal(r.turn, 0, 'a capture earns a bonus roll');

  // two opponents on the same cell are both captured
  const two = withTokens(fresh(), [[3, BASE, BASE, BASE], [44, 44, BASE, BASE]]);
  const both = ok(roll(two, [2]));
  assert.deepEqual(both.players[1].tokens.slice(0, 2), [BASE, BASE]);

  // cell 8 is a star: red 6 -> 8, green at step 47 sits on cell (13+47)%52 = 8
  const safe = ok(roll(withTokens(fresh(), [[6, BASE, BASE, BASE], [47, BASE, BASE, BASE]]), [2]));
  assert.equal(safe.players[1].tokens[0], 47, 'safe cells cannot be captured on');
  assert.equal(safe.turn, 1);

  // your own tokens are never captured
  const own = ok(roll(withTokens(fresh(), [[3, 5, BASE, BASE]]), [2]));
  // two tokens can move (3 -> 5, 5 -> 7), so the player must choose
  assert.equal(own.phase, 'move');
  const chosen = ok(pick(own, 0));
  assert.equal(chosen.players[0].tokens[1], 5);
}

// ---------- winning
{
  const c = withTokens(fresh(), [[HOME, HOME, HOME, 52]]);
  const w = ok(roll(c, [4]));
  assert.equal(w.winnerId, 'u0');
  assert.equal(w.lastEvent, 'win');
  assert.ok(w.players[0].tokens.every((t) => t === HOME));
  assert.equal(err(roll(w, [1])), 'The game is already over.');
}

// ---------- input validation (inputs come from untrusted clients)
{
  const rolled = ok(roll(withTokens(fresh(), [[10, 20, BASE, BASE]]), [4])); // phase 'move'
  assert.equal(err(roll(rolled, [3])), 'Choose a token to move.', 'cannot roll while a choice is pending');
  for (const bad of [{ token: 5 }, { token: -1 }, { token: 2 }, { token: 1.5 }, { token: '0' }, { token: NaN }, {}, 'x', 0, [], true]) {
    assert.ok('error' in ludo.move(rolled, 'u0', bad, rig([])), `rejects ${JSON.stringify(bad)}`);
  }
  assert.ok(!('error' in ludo.move(rolled, 'u0', { token: 1 }, rig([]))), 'a movable token is accepted');
  assert.equal(err(ludo.move(fresh(), 'u0', { token: 0 }, rig([]))), 'Roll the dice first.');
  assert.equal(err(ludo.move(fresh(), 'u1', undefined, rig([3]))), 'It is not your turn.');
  assert.equal(err(ludo.move(rolled, 'u1', { token: 0 }, rig([]))), 'It is not your turn.');
}

// ---------- timeouts
{
  assert.equal(err(ludo.skip(fresh(), everyone(4), T0 + TURN_MS - 1)), 'The turn has not expired yet.');
  const passed = ok(ludo.skip(fresh(), everyone(4), T0 + TURN_MS));
  assert.equal(passed.turn, 1);
  assert.equal(passed.turnDeadline, T0 + 2 * TURN_MS);
  assert.equal(passed.version, 1);

  const waiting = ok(roll(withTokens(fresh(), [[10, 20, BASE, BASE]]), [4]));
  const auto = ok(ludo.skip(waiting, everyone(4), T0 + TURN_MS));
  assert.equal(auto.players[0].tokens[1], 24, 'the furthest token is moved for an idle player');
  assert.equal(auto.turn, 1);
}

// ---------- players who leave
{
  const three = fresh(3);
  const only = new Set(['u0', 'u2']);
  const next = ok(ludo.move(withTokens(three, [], 2), 'u2', undefined, rig([3], only)));
  assert.equal(next.turn, 0, 'u1 left, so the turn goes from u2 to u0');

  const skipLeaver = ok(ludo.move(three, 'u0', undefined, rig([3], only)));
  assert.equal(skipLeaver.turn, 2, 'u1 left: after u0 comes u2');

  const winner = ok(ludo.move(fresh(2), 'u0', undefined, rig([3], new Set(['u0']))));
  assert.equal(winner.winnerId, 'u0', 'the last player in the room wins');
  const idle = ok(ludo.skip(fresh(2), new Set(['u1']), T0 + TURN_MS));
  assert.equal(idle.winnerId, 'u1');
}

// ---------- parity with the offline Dart controller
{
  const file = path.join(__dirname, 'fixtures', 'ludo_parity.json');
  const { games } = JSON.parse(fs.readFileSync(file, 'utf-8'));
  assert.ok(games.length >= 30);
  let actions = 0;
  games.forEach((g: any, gi: number) => {
    const n = g.players as number;
    const rolls = [...g.rolls];
    let st = ludo.init(users(n), T0);
    g.steps.forEach((step: any, i: number) => {
      const turnUser = `u${st.turn}`;
      st = ok(ludo.move(st, turnUser, undefined, rig(rolls, everyone(n))));
      if (st.phase === 'move') {
        // the recorded games always pick the lowest token id
        st = ok(ludo.move(st, turnUser, { token: Math.min(...st.movable) }, rig([], everyone(n))));
      }
      const label = `game ${gi} (${n} players), roll #${i}`;
      assert.deepEqual(st.players.map((p) => p.tokens), step.tokens, `${label}: tokens`);
      assert.equal(st.turn, step.turn, `${label}: whose turn`);
      const winnerIdx = st.winnerId ? users(n).indexOf(st.winnerId) : null;
      assert.equal(winnerIdx, step.winner, `${label}: winner`);
      actions++;
    });
    assert.equal(rolls.length, 0, `game ${gi}: every recorded roll was used`);
  });
  console.log(`parity: ${games.length} recorded Dart games / ${actions} turns replayed identically`);
}

// ---------- random play never breaks an invariant
{
  let seed = 12345;
  const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 2 ** 32);
  let finished = 0;
  const total = 120;
  for (let g = 0; g < total; g++) {
    const n = 2 + (g % 3);
    let st = ludo.init(users(n), T0);
    const active = everyone(n);
    const rng = { active, now: T0, randomInt: (a: number, b: number) => a + Math.floor(rnd() * (b - a)) };
    for (let i = 0; i < 8000 && st.winnerId === null; i++) {
      const who = `u${st.turn}`;
      const version = st.version;
      let r: any;
      if (st.phase === 'move') {
        const choice = st.movable[Math.floor(rnd() * st.movable.length)];
        r = ludo.move(st, who, { token: choice }, rng);
      } else {
        r = ludo.move(st, who, undefined, rng);
      }
      st = ok(r);
      assert.equal(st.version, version + 1);
      for (const p of st.players) {
        assert.equal(p.tokens.length, 4);
        for (const t of p.tokens) assert.ok(Number.isInteger(t) && t >= BASE && t <= HOME, `token ${t} out of range`);
      }
      if (st.phase === 'move') {
        assert.ok(st.movable.length >= 2, 'a lone legal token is auto-played');
        assert.equal(st.dice !== null, true);
        assert.deepEqual([...st.movable].sort(), legalMoves(st.players[st.turn].tokens, st.dice!).sort());
      }
      assert.ok(st.consecutiveSixes >= 0 && st.consecutiveSixes < 3);
      assert.ok(st.turn >= 0 && st.turn < n);
    }
    if (st.winnerId !== null) finished++;
  }
  assert.ok(finished >= total * 0.95, `${finished}/${total} random games finished`);
  console.log(`random play: ${finished}/${total} games finished, invariants held on every move`);
}

console.log('PASS: ludo rules (setup, sixes, auto-move, home, captures, win, validation, timeouts, leavers, parity)');
