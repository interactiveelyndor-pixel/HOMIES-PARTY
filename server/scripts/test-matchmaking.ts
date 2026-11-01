import assert from 'node:assert/strict';
import { Matchmaker, MatchDeps } from '../src/matchmaking';

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

function setup(opts?: { blocked?: [string, string][]; timeoutMs?: number; need?: number; slowBlockMs?: number }) {
  const sent: { socketId: string; event: string; payload: any }[] = [];
  const rooms: { gameType: string; users: string[] }[] = [];
  const connected = new Set<string>();
  let matchedCalls = 0;
  const deps: MatchDeps = {
    isBlocked: async (a, b) => {
      if (opts?.slowBlockMs) await wait(opts.slowBlockMs);
      return (opts?.blocked ?? []).some(([x, y]) => (x === a && y === b) || (x === b && y === a));
    },
    createRoom: async (gameType, users) => {
      rooms.push({ gameType, users });
      return { code: `ROOM${rooms.length}`, gameType, users };
    },
    send: (socketId, event, payload) => sent.push({ socketId, event, payload }),
    isConnected: (id) => connected.has(id),
    matched: () => { matchedCalls++; },
  };
  const mm = new Matchmaker(deps, { timeoutMs: opts?.timeoutMs ?? 5000, playersFor: () => opts?.need ?? 2 });
  const connect = (...ids: string[]) => ids.forEach((i) => connected.add(i));
  return { mm, sent, rooms, connect, connected, matched: () => matchedCalls };
}

(async () => {
  // a lone player waits
  {
    const t = setup(); t.connect('sa');
    const r = await t.mm.join('A', 'sa', 'connect4');
    assert.equal(r.status, 'searching');
    assert.equal(t.mm.queueSize('connect4'), 1);
    assert.equal(t.rooms.length, 0);
    t.mm.cancel('A');
  }

  // two players for the same game are matched once, and both are told
  {
    const t = setup(); t.connect('sa', 'sb');
    await t.mm.join('A', 'sa', 'connect4');
    const r = await t.mm.join('B', 'sb', 'connect4');
    assert.equal(r.status, 'matched');
    assert.deepEqual(t.rooms, [{ gameType: 'connect4', users: ['A', 'B'] }]);
    assert.deepEqual(t.sent.filter((s) => s.event === 'match:found').map((s) => s.socketId).sort(), ['sa', 'sb']);
    assert.equal(t.matched(), 1);
    assert.equal(t.mm.queueSize('connect4'), 0);
  }

  // different games never match each other
  {
    const t = setup(); t.connect('sa', 'sb');
    await t.mm.join('A', 'sa', 'connect4');
    assert.equal((await t.mm.join('B', 'sb', 'snl')).status, 'searching');
    assert.equal(t.rooms.length, 0);
    t.mm.cancel('A'); t.mm.cancel('B');
  }

  // joining twice does not match you with yourself, and keeps one entry
  {
    const t = setup(); t.connect('sa', 'sa2');
    await t.mm.join('A', 'sa', 'connect4');
    const r = await t.mm.join('A', 'sa2', 'connect4');
    assert.equal(r.status, 'searching');
    assert.equal(t.mm.queueSize('connect4'), 1);
    assert.equal(t.rooms.length, 0);
    t.mm.cancel('A');
  }

  // blocked pairs are never matched, but each can match someone else
  {
    const t = setup({ blocked: [['A', 'B']] }); t.connect('sa', 'sb', 'sc');
    await t.mm.join('A', 'sa', 'connect4');
    assert.equal((await t.mm.join('B', 'sb', 'connect4')).status, 'searching');
    assert.equal(t.rooms.length, 0);
    assert.equal((await t.mm.join('C', 'sc', 'connect4')).status, 'matched');
    assert.deepEqual(t.rooms[0].users, ['A', 'C'], 'oldest eligible waiter is chosen');
    assert.equal(t.mm.queueSize('connect4'), 1, 'B is still waiting');
    t.mm.cancel('B');
  }

  // cancel and disconnect leave the queue
  {
    const t = setup(); t.connect('sa', 'sb', 'sc');
    await t.mm.join('A', 'sa', 'connect4');
    assert.equal(t.mm.cancel('A'), true);
    assert.equal(t.mm.cancel('A'), false);
    await t.mm.join('B', 'sb', 'connect4');
    t.mm.disconnect('sb');
    assert.equal(t.mm.queueSize('connect4'), 0);
    assert.equal((await t.mm.join('C', 'sc', 'connect4')).status, 'searching', 'nobody left to match');
    t.mm.cancel('C');
  }

  // a waiting player whose socket died is skipped, not matched
  {
    const t = setup(); t.connect('sa', 'sb');
    await t.mm.join('A', 'sa', 'connect4');
    t.connected.delete('sa');
    assert.equal((await t.mm.join('B', 'sb', 'connect4')).status, 'searching');
    assert.equal(t.rooms.length, 0);
    assert.equal(t.mm.queueSize('connect4'), 1, 'only B remains');
    t.mm.cancel('B');
  }

  // waiting times out, and the player is told
  {
    const t = setup({ timeoutMs: 40 }); t.connect('sa');
    await t.mm.join('A', 'sa', 'connect4');
    await wait(90);
    assert.equal(t.mm.queueSize('connect4'), 0);
    assert.deepEqual(t.sent.filter((s) => s.event === 'match:timeout').map((s) => s.socketId), ['sa']);
  }

  // a timeout that was cancelled in time never fires
  {
    const t = setup({ timeoutMs: 40 }); t.connect('sa');
    await t.mm.join('A', 'sa', 'connect4');
    t.mm.cancel('A');
    await wait(90);
    assert.equal(t.sent.length, 0);
  }

  // simultaneous joins: exactly floor(n/2) matches, nobody matched twice
  {
    const t = setup({ slowBlockMs: 5 });
    const users = ['A', 'B', 'C', 'D', 'E'];
    users.forEach((u) => t.connect('s' + u));
    const results = await Promise.all(users.map((u) => t.mm.join(u, 's' + u, 'connect4')));
    assert.equal(t.rooms.length, 2);
    const seen = t.rooms.flatMap((r) => r.users);
    assert.equal(new Set(seen).size, 4, 'no player appears in two rooms');
    // the first of each pair was told 'searching' before its partner arrived
    assert.equal(results.filter((r) => r.status === 'matched').length, 2);
    assert.equal(t.mm.queueSize('connect4'), 1);
    t.mm.disconnect('s' + users.find((u) => !seen.includes(u))!);
  }

  // a room that fails to create tells both players and leaves the queue clean
  {
    const t = setup(); t.connect('sa', 'sb');
    const failing = new Matchmaker(
      {
        isBlocked: async () => false,
        createRoom: async () => { throw new Error('db down'); },
        send: (socketId, event, payload) => t.sent.push({ socketId, event, payload }),
        isConnected: () => true,
        matched: () => { throw new Error('must not be called'); },
      },
      { timeoutMs: 5000, playersFor: () => 2 }
    );
    await failing.join('A', 'sa', 'connect4');
    await failing.join('B', 'sb', 'connect4');
    assert.deepEqual(t.sent.filter((s) => s.event === 'match:error').map((s) => s.socketId).sort(), ['sa', 'sb']);
    assert.equal(failing.queueSize('connect4'), 0);
  }

  // bigger tables: three players needed
  {
    const t = setup({ need: 3 }); t.connect('sa', 'sb', 'sc');
    await t.mm.join('A', 'sa', 'snl');
    assert.equal((await t.mm.join('B', 'sb', 'snl')).status, 'searching');
    assert.equal((await t.mm.join('C', 'sc', 'snl')).status, 'matched');
    assert.deepEqual(t.rooms[0].users, ['A', 'B', 'C']);
  }

  console.log('PASS: matchmaking (pairing, blocks, cancel, disconnect, timeout, races, failures)');
  process.exit(0);
})().catch((e) => { console.error('FAIL:', e); process.exit(1); });
