import assert from 'node:assert/strict';
import { initSnlState, applyRoll, skipExpiredTurn, SnlState, TURN_MS } from '../src/snl';

const T0 = 1_000_000;
const all = new Set(['a', 'b']);
const ok = (r: any): SnlState => { assert.ok(!('error' in r), r.error); return r.state; };

let s = initSnlState(['a', 'b'], T0);
assert.deepEqual(applyRoll(s, 'b', 3, all, T0), { error: 'It is not your turn.' });
s = ok(applyRoll(s, 'a', 3, all, T0));
assert.equal(s.players[0].position, 3);
assert.equal(s.turn, 1, 'a 6 gives no bonus; turn passes');
s = ok(applyRoll(s, 'b', 4, all, T0)); // ladder 4 -> 25
assert.equal(s.players[1].position, 25);
s = ok(applyRoll(s, 'a', 6, all, T0)); // 3+6=9 ladder -> 31
assert.equal(s.players[0].position, 31);
s.players[1].position = 16; s.turn = 1;
s = ok(applyRoll(s, 'b', 1, all, T0)); // snake 17 -> 7
assert.equal(s.players[1].position, 7);
s.players[0].position = 98; s.turn = 0;
s = ok(applyRoll(s, 'a', 5, all, T0)); // overshoot
assert.equal(s.players[0].position, 98);
s.turn = 0;
s = ok(applyRoll(s, 'a', 2, all, T0)); // exact -> win
assert.equal(s.winnerId, 'a');
assert.ok('error' in applyRoll(s, 'b', 1, all, T0));
// leaver: b left, a is the only one remaining -> a wins
const s2 = ok(applyRoll(initSnlState(['a', 'b'], T0), 'a', 1, new Set(['a']), T0));
assert.equal(s2.winnerId, 'a');
// turn skips a player who left (3 players, b gone)
const s3 = ok(applyRoll(initSnlState(['a', 'b', 'c'], T0), 'a', 1, new Set(['a', 'c']), T0));
assert.equal(s3.turn, 1);
const s4 = ok(applyRoll(s3, 'c', 1, new Set(['a', 'c']), T0));
assert.equal(s4.players[2].position, 1);
// timeouts
let t = initSnlState(['a', 'b'], T0);
assert.ok('error' in skipExpiredTurn(t, all, T0 + TURN_MS - 1), 'not expired yet');
t = ok(skipExpiredTurn(t, all, T0 + TURN_MS));
assert.equal(t.turn, 1);
assert.equal(t.turnDeadline, T0 + 2 * TURN_MS);
assert.equal(t.players[0].position, 0, 'skip does not move anyone');
assert.equal(ok(skipExpiredTurn(initSnlState(['a', 'b', 'c'], T0), new Set(['a', 'c']), T0 + TURN_MS)).turn, 2);
assert.equal(ok(skipExpiredTurn(initSnlState(['a', 'b'], T0), new Set(['b']), T0 + TURN_MS)).winnerId, 'b');
// rematch state must out-version the old one so clients accept it
assert.ok(initSnlState(['a', 'b'], T0, 9).version > 8);
console.log('PASS: snl rules');
