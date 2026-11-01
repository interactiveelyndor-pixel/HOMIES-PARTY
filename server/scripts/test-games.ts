import assert from 'node:assert/strict';
import { connect4, lineThrough, TURN_MS, Connect4State } from '../src/games/connect4';
import { GAMES, getGame } from '../src/games/registry';
import { isOver } from '../src/games/types';

const T0 = 1_000_000;
const both = new Set(['a', 'b']);
const ctx = (active = both, now = T0) => ({ active, now, randomInt: () => 1 });
const ok = (r: any): Connect4State => { assert.ok(!('error' in r), r.error); return r.state; };
const col = (column: unknown) => ({ column });

// Plays columns alternately, a first.
function play(cols: number[]): Connect4State {
  let s = connect4.init(['a', 'b'], T0);
  cols.forEach((c, i) => { s = ok(connect4.move(s, i % 2 === 0 ? 'a' : 'b', col(c), ctx())); });
  return s;
}

// --- registry
assert.deepEqual(Object.keys(GAMES).sort(), ['bluff', 'connect4', 'ludo', 'snl', 'wordrush']);
assert.equal(getGame('connect4')?.id, 'connect4');
assert.equal(getGame('__proto__'), undefined);
assert.equal(getGame('constructor'), undefined);
assert.equal(getGame('chess'), undefined);

// --- basics
let s = connect4.init(['a', 'b'], T0);
assert.throws(() => connect4.init(['a'], T0));
assert.equal(s.turnDeadline, T0 + TURN_MS);
assert.deepEqual(connect4.move(s, 'b', col(3), ctx()), { error: 'It is not your turn.' });
s = ok(connect4.move(s, 'a', col(3), ctx()));
assert.equal(s.board[5][3], 1);
assert.equal(s.turn, 1);
assert.equal(s.version, 1);
s = ok(connect4.move(s, 'b', col(3), ctx()));
assert.equal(s.board[4][3], 2);

// --- input validation (inputs come from untrusted clients)
for (const bad of [undefined, null, {}, { column: -1 }, { column: 7 }, { column: 1.5 }, { column: '3' }, 'x', { column: NaN }]) {
  assert.ok('error' in connect4.move(s, 'a', bad, ctx()), `rejects ${JSON.stringify(bad)}`);
}

// --- full column
let full = connect4.init(['a', 'b'], T0);
for (let i = 0; i < 6; i++) full = ok(connect4.move(full, i % 2 === 0 ? 'a' : 'b', col(0), ctx()));
assert.deepEqual(connect4.move(full, 'a', col(0), ctx()), { error: 'That column is full.' });

// --- wins
assert.equal(play([0, 0, 1, 1, 2, 2, 3]).winnerId, 'a');           // horizontal
assert.equal(play([0, 1, 0, 1, 0, 1, 0]).winnerId, 'a');           // vertical
assert.equal(play([0, 1, 1, 2, 3, 2, 2, 3, 3, 6, 3]).winnerId, 'a'); // rising diagonal
assert.equal(play([6, 5, 5, 4, 3, 4, 4, 3, 3, 0, 3]).winnerId, 'a'); // falling diagonal
const won = play([0, 0, 1, 1, 2, 2, 3]);
assert.equal(won.winningCells.length, 4);
assert.ok(isOver(won));
assert.deepEqual(connect4.move(won, 'b', col(4), ctx()), { error: 'The game is already over.' });

// --- draw: the same no-four pattern the Dart tests use
const rowA = [1, 1, 2, 2, 1, 1, 2];
const rowB = [2, 2, 1, 1, 2, 2, 1];
const pattern = Array.from({ length: 6 }, (_, r) => (r % 2 === 0 ? rowA : rowB));
for (let r = 0; r < 6; r++) for (let c = 0; c < 7; c++) assert.equal(lineThrough(pattern, r, c).length, 0);
// Fill that pattern bottom-up through real moves is order dependent, so check the
// draw rule directly: one empty top cell left, last disc completes the board.
let almost = connect4.init(['a', 'b'], T0);
almost = { ...almost, board: pattern.map((r, i) => (i === 0 ? r.map((v, c) => (c === 0 ? 0 : v)) : [...r])) };
almost.turn = pattern[0][0] - 1; // whoever owns that cell in the pattern
const finisher = almost.players[almost.turn].userId;
const drawn = ok(connect4.move(almost, finisher, col(0), ctx()));
assert.equal(drawn.draw, true);
assert.equal(drawn.winnerId, null);
assert.ok(isOver(drawn));

// --- leavers
const solo = ok(connect4.move(connect4.init(['a', 'b'], T0), 'a', col(3), ctx(new Set(['a']))));
assert.equal(solo.winnerId, 'a', 'last player in the room wins');

// --- timeouts
let t = connect4.init(['a', 'b'], T0);
assert.ok('error' in connect4.skip(t, both, T0 + TURN_MS - 1));
t = ok(connect4.skip(t, both, T0 + TURN_MS));
assert.equal(t.turn, 1);
assert.equal(t.turnDeadline, T0 + 2 * TURN_MS);
assert.equal(t.board.flat().filter(Boolean).length, 0, 'a skip places no disc');
assert.equal(ok(connect4.skip(connect4.init(['a', 'b'], T0), new Set(['b']), T0 + TURN_MS)).winnerId, 'b');

// --- rematch bumps the version
assert.equal(connect4.init(['a', 'b'], T0, 9).version, 9);

// --- the snl adapter still plays by the old rules
const snl = GAMES.snl;
let g = snl.init(['a', 'b'], T0);
assert.equal(g.turn, 0);
const moved: any = snl.move(g, 'a', undefined, { active: both, now: T0, randomInt: () => 3 });
assert.equal(moved.state.players[0].position, 3);
assert.ok('error' in snl.move(g, 'b', undefined, { active: both, now: T0, randomInt: () => 3 }));

console.log('PASS: game framework (registry, connect4 rules, snl adapter)');
