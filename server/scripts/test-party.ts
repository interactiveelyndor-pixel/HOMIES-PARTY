import assert from 'node:assert/strict';
import { pickGame, scoreRound, newParty } from '../src/party';

// 2 players: every game that takes two can come up; 3-4 players: never Connect Four.
const seen2 = new Set<string>();
for (let i = 0; i < 200; i++) seen2.add(pickGame(2, null)!);
assert.deepEqual([...seen2].sort(), ['connect4', 'ludo', 'snl', 'wordrush']);
const seen3 = new Set<string>();
for (let i = 0; i < 300; i++) seen3.add(pickGame(3, null)!);
assert.deepEqual([...seen3].sort(), ['bluff', 'ludo', 'snl', 'wordrush'], 'Bluff needs 3+ players');
for (let i = 0; i < 200; i++) assert.notEqual(pickGame(3, null), 'connect4');
for (let i = 0; i < 200; i++) assert.notEqual(pickGame(4, null), 'connect4');
assert.equal(pickGame(1, null), null, 'one player: nothing fits');
assert.equal(pickGame(5, null), null, 'five players: nothing fits');
for (let i = 0; i < 200; i++) assert.notEqual(pickGame(2, 'ludo'), 'ludo', 'no immediate repeat when there is a choice');
console.log('PASS: random game choice respects player counts and avoids repeats');

const st = (winnerId: string | null) => ({ players: [], turn: 0, winnerId, draw: winnerId === null, version: 1, turnDeadline: 0 });
let p = { ...newParty(2), round: 1 };
p = scoreRound(p, 'snl', st('a'), ['a', 'b', 'c']);
assert.deepEqual(p.scores, { a: 3, b: 1, c: 1 });
assert.equal(p.finished, false);
p = { ...p, round: 2 };
p = scoreRound(p, 'ludo', st(null), ['a', 'b']); // draw; c left
assert.deepEqual(p.scores, { a: 5, b: 3, c: 1 });
assert.equal(p.finished, true);
assert.deepEqual(p.history.map((h) => h.gameType), ['snl', 'ludo']);
console.log('PASS: scoring (win 3, played 1, draw 2, leavers nothing)');
