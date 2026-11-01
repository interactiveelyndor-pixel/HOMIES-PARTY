// Offline integration test: runs the real server, routes, SQL and sockets
// against DATABASE_URL (migrated), with ONLY Firebase token verification stubbed
// (the bearer token is used directly as the Firebase uid). No Firebase needed.
//   DATABASE_URL=postgresql://... npm run test:integration
import assert from 'node:assert/strict';
import { io as connect, Socket } from 'socket.io-client';
import { purgeOldEvents } from '../src/events';

process.env.PORT = process.env.TEST_PORT || '3999';
process.env.HOST = '127.0.0.1';
const ADMIN = 'test-admin-token-1234567890';
process.env.ADMIN_TOKEN = ADMIN;
process.env.MATCH_TIMEOUT_MS = '700';
process.env.FEATURE_PUBLIC_DISCOVERY = 'true'; // flag default for these tests; one test flips it
process.env.DISABLE_SWEEPER = 'true'; // the sweeper is driven by hand below
const deletedFirebaseUsers: string[] = [];
const stubPath = require.resolve('../src/firebase');
require.cache[stubPath] = {
  id: stubPath, filename: stubPath, loaded: true, children: [], paths: [], path: '',
  exports: { firebaseAuth: { verifyIdToken: async (t: string) => ({ uid: t }), deleteUser: async (uid: string) => { deletedFirebaseUsers.push(uid); } } },
} as any;

const BASE = `http://127.0.0.1:${process.env.PORT}`;
const run = Date.now().toString(36);
const uidOf = (n: string) => `${n}-${run}`;

let autoConsent = true; // most tests want ordinary, already-consented players

async function api(method: string, path: string, who: string, body?: unknown) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${uidOf(who)}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const out = { status: res.status, json: text ? JSON.parse(text) : {} };
  if (autoConsent && path === '/v1/auth/guest' && res.ok) {
    await fetch(BASE + '/v1/me/consent', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${uidOf(who)}` },
      body: JSON.stringify({ policyVersion: '1', ageBand: '18plus' }),
    });
  }
  return out;
}
async function admin(method: string, path: string, body?: unknown, token: string | null = ADMIN) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { 'x-admin-token': token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : {} };
}
const pass = (m: string) => console.log('PASS:', m);
const expectStatus = (r: { status: number; json: any }, s: number, label: string) => {
  assert.equal(r.status, s, `${label}: expected ${s}, got ${r.status} ${JSON.stringify(r.json)}`);
  pass(label);
};

function sock(who: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = connect(BASE, { auth: { token: uidOf(who) }, transports: ['websocket'] });
    s.on('connect', () => resolve(s));
    s.on('connect_error', reject);
  });
}
const ack = (s: Socket, ev: string, data: unknown) =>
  new Promise<any>((resolve) => s.emit(ev, data, resolve));

async function startedRoom(host: string, others: string[], gameType?: string) {
  const created = await api('POST', '/v1/rooms', host, gameType ? { gameType } : { maxPlayers: 4 });
  assert.equal(created.status, 201, JSON.stringify(created.json));
  const code = created.json.code as string;
  for (const o of others) assert.equal((await api('POST', '/v1/rooms/join', o, { code })).status, 200);
  for (const w of [host, ...others]) assert.equal((await api('POST', `/v1/rooms/${code}/ready`, w, { ready: true })).status, 200);
  const started = await api('POST', `/v1/rooms/${code}/start`, host);
  assert.equal(started.status, 200, JSON.stringify(started.json));
  return { code, room: started.json };
}

async function main() {
  const { pool } = await import('../src/db');
  await import('../src/server');
  for (let i = 0; i < 50; i++) {
    try { if ((await fetch(BASE + '/health')).ok) break; } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 100));
  }

  // ---- users
  const ids: Record<string, string> = {};
  for (const n of ['A', 'B', 'C', 'D']) {
    const r = await api('POST', '/v1/auth/guest', n, {});
    assert.ok(r.status === 200 || r.status === 201);
    ids[n] = r.json.id;
  }
  pass('registered A, B, C, D');

  // ---- rooms: game type + start
  expectStatus(await api('POST', '/v1/rooms', 'A', { gameType: 'chess' }), 400, 'unsupported gameType rejected');
  const r1 = await startedRoom('A', ['B']);
  assert.equal(r1.room.gameType, 'snl');
  assert.equal(r1.room.gameState.players.length, 2);
  assert.equal(r1.room.gameState.players[0].userId, ids.A);
  pass('room starts with server-side game state (A moves first)');

  // ---- social gating
  expectStatus(await api('POST', '/v1/friends/requests', 'C', { userId: ids.A }), 404, 'friend request to a stranger (never played) is refused');
  expectStatus(await api('POST', '/v1/friends/requests', 'A', { userId: 'not-a-uuid' }), 400, 'invalid userId rejected');
  expectStatus(await api('POST', '/v1/friends/requests', 'A', { userId: ids.A }), 400, 'cannot add yourself');
  const recent = await api('GET', '/v1/players/recent', 'A');
  assert.deepEqual(recent.json.players.map((p: any) => [p.userId, p.relation]), [[ids.B, 'none']]);
  pass('recent players lists B');

  // ---- friend request lifecycle
  expectStatus(await api('POST', '/v1/friends/requests', 'A', { userId: ids.B }), 201, 'A -> B request pending');
  expectStatus(await api('POST', '/v1/friends/requests', 'A', { userId: ids.B }), 409, 'duplicate request refused');
  const reqs = await api('GET', '/v1/friends/requests', 'B');
  assert.equal(reqs.json.incoming.length, 1);
  assert.equal((await api('GET', '/v1/friends/requests', 'A')).json.outgoing.length, 1);
  // only the recipient can accept
  expectStatus(await api('POST', `/v1/friends/requests/${reqs.json.incoming[0].requestId}/accept`, 'A'), 404, 'sender cannot accept own request');
  expectStatus(await api('POST', `/v1/friends/requests/${reqs.json.incoming[0].requestId}/accept`, 'B'), 200, 'B accepts');
  assert.equal((await api('GET', '/v1/friends', 'A')).json.friends[0].userId, ids.B);
  assert.equal((await api('GET', '/v1/friends', 'B')).json.friends[0].userId, ids.A);
  pass('friendship is mutual');
  expectStatus(await api('POST', '/v1/friends/requests', 'B', { userId: ids.A }), 409, 'request between friends refused');

  // ---- mutual request auto-accepts
  await startedRoom('A', ['C']);
  expectStatus(await api('POST', '/v1/friends/requests', 'C', { userId: ids.A }), 201, 'C -> A pending');
  const mutual = await api('POST', '/v1/friends/requests', 'A', { userId: ids.C });
  assert.equal(mutual.json.status, 'friends');
  pass('crossing requests become a friendship');

  // ---- decline / cancel
  await startedRoom('B', ['D']);
  await api('POST', '/v1/friends/requests', 'D', { userId: ids.B });
  const dReq = (await api('GET', '/v1/friends/requests', 'B')).json.incoming[0].requestId;
  expectStatus(await api('DELETE', `/v1/friends/requests/${dReq}`, 'B'), 200, 'recipient declines');
  assert.equal((await api('GET', '/v1/friends/requests', 'B')).json.incoming.length, 0);

  // ---- unfriend
  expectStatus(await api('DELETE', `/v1/friends/${ids.C}`, 'A'), 200, 'unfriend');
  assert.equal((await api('GET', '/v1/friends', 'C')).json.friends.length, 0);

  // ---- blocking
  expectStatus(await api('POST', '/v1/blocks', 'A', { userId: ids.B }), 201, 'A blocks B');
  assert.equal((await api('GET', '/v1/friends', 'A')).json.friends.length, 0);
  pass('blocking removed the friendship');
  assert.ok(!(await api('GET', '/v1/players/recent', 'A')).json.players.some((p: any) => p.userId === ids.B));
  assert.ok(!(await api('GET', '/v1/players/recent', 'B')).json.players.some((p: any) => p.userId === ids.A));
  pass('blocked players are hidden from each other');
  expectStatus(await api('POST', '/v1/friends/requests', 'B', { userId: ids.A }), 404, 'blocked user cannot send a friend request');
  const aRoom = await api('POST', '/v1/rooms', 'A', {});
  expectStatus(await api('POST', '/v1/rooms/join', 'B', { code: aRoom.json.code }), 403, 'blocked user cannot join the blocker\'s room');
  const bRoom = await api('POST', '/v1/rooms', 'B', {});
  expectStatus(await api('POST', '/v1/rooms/join', 'A', { code: bRoom.json.code }), 403, 'blocker cannot join the blocked user\'s room either');
  assert.equal((await api('GET', '/v1/blocks', 'A')).json.blocked[0].userId, ids.B);
  expectStatus(await api('DELETE', `/v1/blocks/${ids.B}`, 'A'), 200, 'unblock');
  expectStatus(await api('POST', '/v1/rooms/join', 'B', { code: aRoom.json.code }), 200, 'after unblock B can join');

  // ---- reports
  expectStatus(await api('POST', '/v1/reports', 'A', { userId: ids.B, reason: 'nonsense' }), 400, 'invalid report reason rejected');
  expectStatus(await api('POST', '/v1/reports', 'A', { userId: ids.B, reason: 'spam', details: 'x'.repeat(501) }), 400, 'overlong details rejected');
  expectStatus(await api('POST', '/v1/reports', 'A', { userId: ids.B, reason: 'harassment', details: 'test' }), 201, 'report stored');
  expectStatus(await api('POST', '/v1/reports', 'C', { userId: ids.D, reason: 'spam' }), 404, 'cannot report someone you never played with');
  const saved = await pool.query('SELECT reason, details FROM reports WHERE reporter_id = $1', [ids.A]);
  assert.equal(saved.rows.length, 1);

  // ---- online Snakes & Ladders over sockets
  const sa = await sock('A');
  const sb = await sock('B');
  assert.equal((await ack(sa, 'room:subscribe', { code: r1.code })).success, true);
  await ack(sb, 'room:subscribe', { code: r1.code });
  const seen: any[] = [];
  sb.on('game:state', (e) => seen.push(e));

  assert.match((await ack(sb, 'game:roll', { code: r1.code })).message, /not your turn/);
  pass('rolling out of turn is rejected');
  const rolled = await ack(sa, 'game:roll', { code: r1.code });
  assert.equal(rolled.success, true);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(seen.length, 1);
  assert.equal(seen[0].state.version, 1);
  assert.equal(seen[0].state.turn, 1);
  pass('A rolled; B received the new state; turn passed');

  assert.match((await ack(sa, 'game:skip', { code: r1.code })).message, /not expired/);
  pass('turn cannot be skipped before the deadline');
  await pool.query(
    `UPDATE rooms SET game_state = jsonb_set(game_state, '{turnDeadline}', '0') WHERE code = $1`, [r1.code]);
  assert.equal((await ack(sa, 'game:skip', { code: r1.code })).success, true);
  assert.equal((await pool.query('SELECT game_state FROM rooms WHERE code = $1', [r1.code])).rows[0].game_state.turn, 0);
  pass('expired turn is skipped by the server');

  assert.match((await ack(sa, 'game:rematch', { code: r1.code })).message, /only possible after/);
  await pool.query(
    `UPDATE rooms SET status = 'finished',
       game_state = jsonb_set(game_state, '{winnerId}', to_jsonb($2::text)) WHERE code = $1`, [r1.code, ids.A]);
  assert.match((await ack(sb, 'game:roll', { code: r1.code })).message, /not in progress/);
  const rem = await ack(sb, 'game:rematch', { code: r1.code });
  assert.equal(rem.success, true);
  assert.equal(rem.state.winnerId, null);
  assert.ok(rem.state.version > 2);
  const after = await pool.query('SELECT status FROM rooms WHERE code = $1', [r1.code]);
  assert.equal(after.rows[0].status, 'playing');
  pass('rematch restarts the game with a higher version');

  // outsiders cannot act in the room
  const sd = await sock('D');
  assert.equal((await ack(sd, 'game:roll', { code: r1.code })).error, 'Forbidden');
  pass('non-member cannot act in a room');

  sa.close(); sb.close(); sd.close();

  // ---- online Connect Four (same framework, different game)
  const ids3: Record<string, string> = {};
  for (const n of ['J', 'K', 'L']) ids3[n] = (await api('POST', '/v1/auth/guest', n, {})).json.id;
  expectStatus(await api('POST', '/v1/rooms', 'J', { gameType: 'connect4', maxPlayers: 4 }), 400, 'Connect Four rejects a 4-player room');
  const c4lobby = await api('POST', '/v1/rooms', 'J', { gameType: 'connect4' });
  assert.equal(c4lobby.json.maxPlayers, 2);
  assert.equal(c4lobby.json.gameType, 'connect4');
  pass('Connect Four room defaults to 2 players');
  await api('POST', '/v1/rooms/join', 'K', { code: c4lobby.json.code });
  expectStatus(await api('POST', '/v1/rooms/join', 'L', { code: c4lobby.json.code }), 409, 'third player cannot join a full Connect Four room');
  for (const w of ['J', 'K']) await api('POST', `/v1/rooms/${c4lobby.json.code}/ready`, w, { ready: true });
  const c4start = await api('POST', `/v1/rooms/${c4lobby.json.code}/start`, 'J');
  assert.equal(c4start.status, 200, JSON.stringify(c4start.json));
  assert.equal(c4start.json.gameState.board.length, 6);
  assert.equal(c4start.json.gameState.board[0].length, 7);
  pass('Connect Four starts with an empty 6x7 board');
  const c4 = c4lobby.json.code as string;

  const sj = await sock('J');
  const sk = await sock('K');
  await ack(sj, 'room:subscribe', { code: c4 });
  await ack(sk, 'room:subscribe', { code: c4 });
  const kSaw: any[] = [];
  sk.on('game:state', (e) => kSaw.push(e));

  assert.match((await ack(sk, 'game:move', { code: c4, move: { column: 3 } })).message, /not your turn/);
  pass('Connect Four: moving out of turn is rejected');
  for (const bad of [{ column: 9 }, { column: -1 }, { column: 'x' }, {}, null]) {
    assert.ok((await ack(sj, 'game:move', { code: c4, move: bad })).error, `rejects ${JSON.stringify(bad)}`);
  }
  assert.ok((await ack(sj, 'game:roll', { code: c4 })).error, 'a roll is not a Connect Four move');
  pass('Connect Four: invalid inputs are rejected');
  assert.equal((await ack(sj, 'game:move', { code: c4, move: { column: 3 } })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(kSaw.at(-1).state.board[5][3], 1);
  assert.equal(kSaw.at(-1).state.turn, 1);
  pass('Connect Four: J dropped a disc; K received the new board');

  // J wins vertically in column 0 (J already holds column 3)
  for (const [who, column] of [['K', 1], ['J', 0], ['K', 1], ['J', 0], ['K', 1], ['J', 0]] as const) {
    const r = await ack(who === 'J' ? sj : sk, 'game:move', { code: c4, move: { column } });
    assert.equal(r.success, true, JSON.stringify(r));
  }
  // J now has three discs in column 0 and K three in column 1 (not yet four); K plays elsewhere
  assert.equal((await ack(sk, 'game:move', { code: c4, move: { column: 2 } })).success, true);
  const winMove = await ack(sj, 'game:move', { code: c4, move: { column: 0 } });
  assert.equal(winMove.success, true);
  assert.equal(winMove.state.winnerId, ids3.J);
  assert.equal(winMove.state.winningCells.length, 4);
  assert.equal((await pool.query('SELECT status FROM rooms WHERE code = $1', [c4])).rows[0].status, 'finished');
  pass('Connect Four: four in a column wins; the room becomes finished');
  assert.match((await ack(sk, 'game:move', { code: c4, move: { column: 4 } })).message, /not in progress/);

  const c4rematch = await ack(sk, 'game:rematch', { code: c4 });
  assert.equal(c4rematch.success, true);
  assert.equal(c4rematch.state.board.flat().filter(Boolean).length, 0);
  assert.ok(c4rematch.state.version > winMove.state.version);
  pass('Connect Four: rematch gives a fresh board and a higher version');

  await pool.query(`UPDATE rooms SET game_state = jsonb_set(game_state, '{turnDeadline}', '0') WHERE code = $1`, [c4]);
  assert.equal((await ack(sk, 'game:skip', { code: c4 })).success, true);
  assert.equal((await pool.query('SELECT game_state FROM rooms WHERE code = $1', [c4])).rows[0].game_state.turn, 1);
  pass('Connect Four: an expired turn is skipped by the server');

  const sl = await sock('L');
  assert.equal((await ack(sl, 'game:move', { code: c4, move: { column: 0 } })).error, 'Forbidden');
  pass('Connect Four: a non-member cannot move');
  sj.close(); sk.close(); sl.close();

  // ---- Quick Match
  const ids4: Record<string, string> = {};
  for (const n of ['M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T']) ids4[n] = (await api('POST', '/v1/auth/guest', n, {})).json.id;
  const once = (s: Socket, ev: string) => new Promise<any>((resolve) => s.once(ev, resolve));

  const sm = await sock('M');
  const sn = await sock('N');
  assert.ok((await ack(sm, 'match:join', { gameType: 'chess' })).error, 'unknown game rejected');
  assert.ok((await ack(sm, 'match:join', {})).error, 'missing game rejected');
  const mFound = once(sm, 'match:found');
  const nFound = once(sn, 'match:found');
  assert.equal((await ack(sm, 'match:join', { gameType: 'connect4' })).status, 'searching');
  assert.equal((await ack(sn, 'match:join', { gameType: 'connect4' })).status, 'matched');
  const [mRoom, nRoom] = [(await mFound).room, (await nFound).room];
  assert.equal(mRoom.code, nRoom.code);
  assert.equal(mRoom.status, 'playing');
  assert.equal(mRoom.gameType, 'connect4');
  assert.equal(mRoom.gameState.players.length, 2);
  assert.ok(mRoom.players.every((p: any) => p.isReady));
  pass('two players who pick the same game are matched into a started room');

  const nSaw: any[] = [];
  sn.on('game:state', (e) => nSaw.push(e));
  const first = mRoom.gameState.players[0].userId === ids4.M ? sm : sn;
  const second = first === sm ? sn : sm;
  const watcher: any[] = first === sm ? nSaw : [];
  if (first === sn) sm.on('game:state', (e) => watcher.push(e));
  assert.equal((await ack(first, 'game:move', { code: mRoom.code, move: { column: 3 } })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(watcher.at(-1).state.board[5][3], 1);
  pass('matched players are already subscribed and can play at once');
  void second;
  const recentM = await api('GET', '/v1/players/recent', 'M');
  assert.ok(recentM.json.players.some((p: any) => p.userId === ids4.N));
  pass('matched players appear in each other\'s recent players');

  // blocked pairs are never matched
  await api('POST', '/v1/blocks', 'O', { userId: ids4.P });
  const so = await sock('O');
  const sp = await sock('P');
  assert.equal((await ack(so, 'match:join', { gameType: 'snl' })).status, 'searching');
  assert.equal((await ack(sp, 'match:join', { gameType: 'snl' })).status, 'searching');
  pass('a blocked pair is not matched with each other');
  assert.equal((await ack(so, 'match:cancel', {})).wasWaiting, true);
  assert.equal((await ack(so, 'match:cancel', {})).wasWaiting, false);
  pass('cancel leaves the queue (and is harmless to repeat)');

  // timeout
  const timedOut = once(sp, 'match:timeout');
  await timedOut;
  pass('a search with nobody to play times out and tells the player');

  // rate limit
  const sq = await sock('Q');
  let limited: any = null;
  for (let i = 0; i < 14 && !limited; i++) {
    const r = await ack(sq, 'match:join', { gameType: 'connect4' });
    if (r.error) limited = r;
  }
  assert.equal(limited?.error, 'Too Many Requests');
  pass('searching again and again is rate limited');

  // a player who disconnected is never matched
  const sr = await sock('R');
  await ack(sr, 'match:join', { gameType: 'connect4' });
  sr.close();
  await new Promise((r) => setTimeout(r, 200));
  const ss = await sock('S');
  assert.equal((await ack(ss, 'match:join', { gameType: 'connect4' })).status, 'searching');
  pass('a disconnected waiter is dropped, not matched');

  // suspended players cannot search
  const st = await sock('T');
  await admin('POST', `/admin/users/${ids4.T}/ban`);
  assert.equal((await ack(st, 'match:join', { gameType: 'connect4' })).error, 'Forbidden');
  await admin('POST', `/admin/users/${ids4.T}/unban`);
  pass('a suspended player cannot search');
  [sm, sn, so, sp, sq, ss, st].forEach((x) => x.close());

  // ---- reactions
  const ids5: Record<string, string> = {};
  for (const n of ['U', 'V', 'W', 'X']) ids5[n] = (await api('POST', '/v1/auth/guest', n, {})).json.id;
  const rx = await startedRoom('U', ['V', 'W']);
  const su = await sock('U');
  const sv = await sock('V');
  const sw = await sock('W');
  const sx = await sock('X');
  for (const x of [su, sv, sw]) await ack(x, 'room:subscribe', { code: rx.code });
  const gotV: any[] = [];
  const gotW: any[] = [];
  const gotU: any[] = [];
  sv.on('game:reaction', (e) => gotV.push(e));
  sw.on('game:reaction', (e) => gotW.push(e));
  su.on('game:reaction', (e) => gotU.push(e));

  assert.equal((await ack(su, 'game:react', { code: rx.code, emoji: '🔥' })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(gotV.at(-1).emoji, '🔥');
  assert.equal(gotV.at(-1).userId, ids5.U);
  assert.equal(gotW.length, 1);
  assert.equal(gotU.length, 1, 'the sender sees their own reaction');
  pass('a reaction reaches everyone in the room');
  for (const bad of ['hello', '<script>', '', 5, null, '🔥🔥']) {
    assert.equal((await ack(su, 'game:react', { code: rx.code, emoji: bad })).error, 'Bad Request', `rejects ${JSON.stringify(bad)}`);
  }
  pass('only the fixed reactions are accepted');
  assert.equal((await ack(sx, 'game:react', { code: rx.code, emoji: '👍' })).error, 'Forbidden');
  assert.equal((await ack(su, 'game:react', { code: 'NOPE22', emoji: '👍' })).error, 'Forbidden');
  pass('only room members can react');

  await api('POST', '/v1/blocks', 'V', { userId: ids5.U });
  gotV.length = 0; gotW.length = 0;
  await ack(su, 'game:react', { code: rx.code, emoji: '😂' });
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(gotV.length, 0, 'V blocked U, so V never sees U\'s reactions');
  assert.equal(gotW.length, 1, 'W still does');
  pass('a player who blocked the sender does not receive their reactions');

  let limitedReact: any = null;
  for (let i = 0; i < 30 && !limitedReact; i++) {
    const r = await ack(sw, 'game:react', { code: rx.code, emoji: '👏' });
    if (r.error) limitedReact = r;
  }
  assert.equal(limitedReact?.error, 'Too Many Requests');
  pass('reactions are rate limited');
  [su, sv, sw, sx].forEach((x) => x.close());

  // ---- online Ludo
  const ids6: Record<string, string> = {};
  for (const n of ['Y', 'Z', 'AA']) ids6[n] = (await api('POST', '/v1/auth/guest', n, {})).json.id;
  const lcreate = await api('POST', '/v1/rooms', 'Y', { gameType: 'ludo', maxPlayers: 2 });
  assert.equal(lcreate.status, 201, JSON.stringify(lcreate.json));
  await api('POST', '/v1/rooms/join', 'Z', { code: lcreate.json.code });
  for (const w of ['Y', 'Z']) await api('POST', `/v1/rooms/${lcreate.json.code}/ready`, w, { ready: true });
  const lstart = await api('POST', `/v1/rooms/${lcreate.json.code}/start`, 'Y');
  assert.equal(lstart.status, 200, JSON.stringify(lstart.json));
  const lc = lcreate.json.code as string;
  assert.deepEqual(lstart.json.gameState.players.map((p: any) => p.color), [0, 2]);
  assert.equal(lstart.json.gameState.players[0].tokens.length, 4);
  pass('Ludo room starts with red and yellow, four tokens each in base');

  const sy = await sock('Y');
  const sz = await sock('Z');
  await ack(sy, 'room:subscribe', { code: lc });
  await ack(sz, 'room:subscribe', { code: lc });
  const zSaw: any[] = [];
  sz.on('game:state', (e) => zSaw.push(e));

  assert.match((await ack(sz, 'game:roll', { code: lc })).message, /not your turn/);
  assert.match((await ack(sy, 'game:move', { code: lc, move: { token: 0 } })).message, /Roll the dice first/);
  pass('Ludo: out-of-turn rolls and moving before rolling are rejected');

  // Play real turns with the server's dice, picking random legal tokens.
  let ludoState: any = lstart.json.gameState;
  let played = 0;
  for (; played < 150 && !ludoState.winnerId; played++) {
    const mine = ludoState.players[ludoState.turn].userId === ids6.Y ? sy : sz;
    const r = ludoState.phase === 'move'
      ? await ack(mine, 'game:move', { code: lc, move: { token: ludoState.movable[played % ludoState.movable.length] } })
      : await ack(mine, 'game:roll', { code: lc });
    assert.equal(r.success, true, JSON.stringify(r));
    assert.equal(r.state.version, ludoState.version + 1);
    ludoState = r.state;
  }
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(zSaw.at(-1).state.version, ludoState.version);
  assert.ok(ludoState.players.every((p: any) => p.tokens.every((t: number) => t >= -1 && t <= 56)));
  pass(`Ludo: ${played} real turns played with server dice; both players stayed in sync`);

  // Finish a game: put red one step from winning, then keep playing until it wins.
  await pool.query(
    `UPDATE rooms SET status = 'playing', game_state = jsonb_set(jsonb_set(jsonb_set(game_state, '{players,0,tokens}', '[56,56,56,52]'), '{phase}', '"roll"'), '{turn}', '0') WHERE code = $1`,
    [lc]);
  let guard = 0;
  let last: any = (await pool.query('SELECT game_state FROM rooms WHERE code = $1', [lc])).rows[0].game_state;
  while (!last.winnerId && guard++ < 200) {
    const mine = last.players[last.turn].userId === ids6.Y ? sy : sz;
    const r = last.phase === 'move'
      ? await ack(mine, 'game:move', { code: lc, move: { token: last.movable[0] } })
      : await ack(mine, 'game:roll', { code: lc });
    assert.equal(r.success, true, JSON.stringify(r));
    last = r.state;
  }
  assert.equal(last.winnerId, ids6.Y);
  assert.equal(last.lastEvent, 'win');
  assert.equal((await pool.query('SELECT status FROM rooms WHERE code = $1', [lc])).rows[0].status, 'finished');
  pass('Ludo: bringing the last token home wins and finishes the room');
  const lrematch = await ack(sz, 'game:rematch', { code: lc });
  assert.equal(lrematch.success, true);
  assert.ok(lrematch.state.players.every((p: any) => p.tokens.every((t: number) => t === -1)));
  pass('Ludo: rematch resets every token to base');

  // Ludo is also available through Quick Match
  const sa2 = await sock('Z');
  const sb2 = await sock('AA');
  const lfound = once(sa2, 'match:found');
  assert.equal((await ack(sa2, 'match:join', { gameType: 'ludo' })).status, 'searching');
  assert.equal((await ack(sb2, 'match:join', { gameType: 'ludo' })).status, 'matched');
  const lroom = (await lfound).room;
  assert.equal(lroom.gameType, 'ludo');
  assert.equal(lroom.gameState.players.length, 2);
  pass('Ludo: Quick Match pairs two players into a started Ludo room');
  [sy, sz, sa2, sb2].forEach((x) => x.close());

  // ---- launch controls: public config, consent and age range, kill switch
  const cfg = await (await fetch(BASE + '/v1/config')).json();
  assert.equal(cfg.policyVersion, '1');
  assert.equal(cfg.features.publicDiscovery, true);
  assert.equal(typeof cfg.minClientVersion, 'string');
  pass('the public config is readable without signing in');

  autoConsent = false;
  const ids7: Record<string, string> = {};
  ids7.CA = (await api('POST', '/v1/auth/guest', 'CA', {})).json.id;
  autoConsent = true;
  const sCA = await sock('CA');
  assert.equal((await api('GET', '/v1/me/eligibility', 'CA')).json.online, false);
  const noConsent = await api('POST', '/v1/rooms', 'CA', {});
  assert.equal(noConsent.status, 403);
  assert.equal(noConsent.json.code, 'CONSENT_REQUIRED');
  pass('playing online needs consent first');
  expectStatus(await api('POST', '/v1/me/consent', 'CA', { policyVersion: '0', ageBand: '18plus' }), 400, 'out-of-date terms are rejected');
  expectStatus(await api('POST', '/v1/me/consent', 'CA', { policyVersion: '1', ageBand: 'adult' }), 400, 'an unknown age range is rejected');
  expectStatus(await api('POST', '/v1/me/consent', 'CA', { policyVersion: '1', ageBand: 'under13' }), 200, 'consent is saved for an under-13 player');
  const e1 = (await api('GET', '/v1/me/eligibility', 'CA')).json;
  assert.equal(e1.online, true);
  assert.equal(e1.social, false);
  expectStatus(await api('POST', '/v1/rooms', 'CA', {}), 201, 'an under-13 player can use private rooms');
  const underFriend = await api('POST', '/v1/friends/requests', 'CA', { userId: ids.A });
  assert.equal(underFriend.status, 403);
  assert.equal(underFriend.json.code, 'SOCIAL_NOT_ALLOWED');
  const underMatch = await ack(sCA, 'match:join', { gameType: 'connect4' });
  assert.equal(underMatch.code, 'SOCIAL_NOT_ALLOWED');
  pass('an under-13 player gets no friend requests or Quick Match');
  expectStatus(await api('POST', '/v1/me/consent', 'CA', { policyVersion: '1', ageBand: '18plus' }), 409, 'an under-13 answer cannot be changed');

  const exp = await api('GET', '/v1/me/export', 'A');
  assert.equal(exp.status, 200);
  assert.equal(exp.json.profile.id, ids.A);
  assert.ok(Array.isArray(exp.json.friends) && Array.isArray(exp.json.consents));
  assert.ok(!JSON.stringify(exp.json).includes('firebase_uid'));
  await api('GET', '/v1/me/export', 'A'); await api('GET', '/v1/me/export', 'A');
  expectStatus(await api('GET', '/v1/me/export', 'A'), 429, 'data export is rate limited');
  pass('a player can export their own data, and nothing internal leaks');

  // the kill switch: turn Quick Match off while running, then back on
  const sKill = await sock('A');
  expectStatus(await admin('POST', '/admin/flags/publicDiscovery', { enabled: false }), 200, 'admin switches Quick Match off');
  assert.equal((await (await fetch(BASE + '/v1/config')).json()).features.publicDiscovery, false);
  assert.equal((await ack(sKill, 'match:join', { gameType: 'connect4' })).code, 'FEATURE_DISABLED');
  pass('with the flag off, Quick Match is refused and the config says so');
  expectStatus(await admin('POST', '/admin/flags/nonsense', { enabled: true }), 400, 'unknown flags are rejected');
  expectStatus(await admin('POST', '/admin/flags/publicDiscovery', { enabled: 'yes' }), 400, 'non-boolean values are rejected');
  expectStatus(await admin('POST', '/admin/flags/publicDiscovery', { enabled: true }, null), 401, 'the flag switch needs the admin token');
  expectStatus(await admin('POST', '/admin/flags/publicDiscovery', { enabled: true }), 200, 'admin switches Quick Match back on');
  assert.equal((await ack(sKill, 'match:join', { gameType: 'connect4' })).status, 'searching');
  await ack(sKill, 'match:cancel', {});
  [sCA, sKill].forEach((x) => x.close());

  // ---- stale and repeated actions are refused (expectedRevision)
  for (const n of ['CD', 'CE']) await api('POST', '/v1/auth/guest', n, {});
  const rv = await startedRoom('CD', ['CE'], 'connect4');
  const sCD = await sock('CD');
  const sCE = await sock('CE');
  await ack(sCD, 'room:subscribe', { code: rv.code });
  await ack(sCE, 'room:subscribe', { code: rv.code });
  const rev0 = rv.room.gameState.version;
  const stale = await ack(sCD, 'game:move', { code: rv.code, move: { column: 3 }, expectedRevision: rev0 + 5 });
  assert.equal(stale.code, 'REVISION_CONFLICT');
  assert.equal((await ack(sCD, 'game:move', { code: rv.code, move: { column: 3 }, expectedRevision: 'x' })).error, 'Bad Request');
  const firstMove = await ack(sCD, 'game:move', { code: rv.code, move: { column: 3 }, expectedRevision: rev0 });
  assert.equal(firstMove.success, true);
  const repeat = await ack(sCD, 'game:move', { code: rv.code, move: { column: 3 }, expectedRevision: rev0 });
  assert.equal(repeat.code, 'REVISION_CONFLICT');
  assert.equal((await pool.query(`SELECT game_state FROM rooms WHERE code = $1`, [rv.code])).rows[0].game_state.board.flat().filter(Boolean).length, 1);
  pass('a stale or repeated action is refused and changes nothing');
  assert.equal((await ack(sCE, 'game:move', { code: rv.code, move: { column: 4 } })).success, true);
  pass('older clients that send no revision keep working');

  // ---- quick phrases
  const sawPhrase: any[] = [];
  sCD.on('game:reaction', (e) => sawPhrase.push(e));
  assert.equal((await ack(sCE, 'game:react', { code: rv.code, emoji: 'Good luck!' })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(sawPhrase.at(-1).emoji, 'Good luck!');
  assert.equal((await ack(sCE, 'game:react', { code: rv.code, emoji: 'Send me your phone number' })).error, 'Bad Request');
  pass('quick phrases work, free text is refused');

  // ---- the server moves things along on its own (no client needed)
  const { sweepOnce } = await import('../src/sweeper');
  await pool.query(`UPDATE rooms SET game_state = jsonb_set(game_state, '{turnDeadline}', '0') WHERE code = $1`, [rv.code]);
  const turnBefore = (await pool.query('SELECT game_state FROM rooms WHERE code = $1', [rv.code])).rows[0].game_state;
  const sweptState: any[] = [];
  sCD.on('game:state', (e) => sweptState.push(e));
  const swept1 = await sweepOnce();
  assert.ok(swept1.turns >= 1);
  const turnAfter = (await pool.query('SELECT game_state FROM rooms WHERE code = $1', [rv.code])).rows[0].game_state;
  assert.equal(turnAfter.version, turnBefore.version + 1);
  assert.notEqual(turnAfter.turn, turnBefore.turn);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(sweptState.at(-1)?.state.version, turnAfter.version);
  pass('an expired turn is skipped by the server itself and players are told');

  // a player who stays disconnected forfeits after the grace period
  for (const n of ['FA', 'FB']) await api('POST', '/v1/auth/guest', n, {});
  const fr = await startedRoom('FA', ['FB'], 'connect4');
  const sFA = await sock('FA');
  const sFB = await sock('FB');
  await ack(sFA, 'room:subscribe', { code: fr.code });
  await ack(sFB, 'room:subscribe', { code: fr.code });
  const fbSaw: any[] = [];
  const fbRoom: any[] = [];
  sFB.on('game:state', (e) => fbSaw.push(e));
  sFB.on('room:updated', (e) => fbRoom.push(e));
  sFA.close();
  await new Promise((r) => setTimeout(r, 300));
  const justNow = await sweepOnce();
  assert.equal((await pool.query('SELECT status FROM rooms WHERE code = $1', [fr.code])).rows[0].status, 'playing', 'still inside the grace period');
  void justNow;
  const later = await sweepOnce(Date.now() + 200_000);
  assert.ok(later.forfeits >= 1);
  const finished = (await pool.query('SELECT status, game_state FROM rooms WHERE code = $1', [fr.code])).rows[0];
  assert.equal(finished.status, 'finished');
  assert.equal(finished.game_state.winnerId, (await api('GET', '/v1/me', 'FB')).json.id);
  assert.equal((await pool.query(`SELECT COUNT(*)::int AS n FROM room_players rp JOIN rooms r ON r.id = rp.room_id WHERE r.code = $1`, [fr.code])).rows[0].n, 1);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(fbSaw.at(-1).state.winnerId, finished.game_state.winnerId);
  assert.ok(fbRoom.length >= 1);
  pass('a player who stays disconnected past the grace period forfeits; the other player wins');
  sFB.close();

  // ---- lobby expiry and host controls
  for (const n of ['K1', 'K2', 'K3']) await api('POST', '/v1/auth/guest', n, {});
  const kid = (await api('GET', '/v1/me', 'K2')).json.id as string;
  const kroom = (await api('POST', '/v1/rooms', 'K1', {})).json.code as string;
  await api('POST', '/v1/rooms/join', 'K2', { code: kroom });
  await api('POST', '/v1/rooms/join', 'K3', { code: kroom });
  const sK2 = await sock('K2');
  await ack(sK2, 'room:subscribe', { code: kroom });
  const kicked: any[] = [];
  sK2.on('room:kicked', (e) => kicked.push(e));
  expectStatus(await api('POST', `/v1/rooms/${kroom}/kick`, 'K3', { userId: kid }), 403, 'only the host can remove players');
  const k1id = (await api('GET', '/v1/me', 'K1')).json.id;
  expectStatus(await api('POST', `/v1/rooms/${kroom}/kick`, 'K1', { userId: k1id }), 400, 'the host cannot remove themselves');
  expectStatus(await api('POST', `/v1/rooms/${kroom}/kick`, 'K1', { userId: 'nope' }), 400, 'a bad user id is rejected');
  const kicking = await api('POST', `/v1/rooms/${kroom}/kick`, 'K1', { userId: kid });
  assert.equal(kicking.status, 200, JSON.stringify(kicking.json));
  assert.ok(!kicking.json.players.some((p: any) => p.userId === kid));
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(kicked.length, 1);
  pass('the host removes a player; they are told');
  expectStatus(await api('POST', '/v1/rooms/join', 'K2', { code: kroom }), 403, 'a removed player cannot rejoin that room');
  expectStatus(await api('POST', `/v1/rooms/${kroom}/kick`, 'K1', { userId: kid }), 404, 'removing someone who is not there is a 404');
  const otherRoom = (await api('POST', '/v1/rooms', 'K1', {})).json.code;
  expectStatus(await api('POST', '/v1/rooms/join', 'K2', { code: otherRoom }), 200, 'a removed player can still join other rooms');
  // not allowed once the game has started
  await api('POST', `/v1/rooms/${kroom}/join`, 'K3', {});
  await api('POST', '/v1/rooms/join', 'K2', { code: otherRoom });
  for (const w of ['K1', 'K3']) await api('POST', `/v1/rooms/${kroom}/ready`, w, { ready: true });
  expectStatus(await api('POST', `/v1/rooms/${kroom}/start`, 'K1'), 200, 'the room starts');
  const k3id = (await api('GET', '/v1/me', 'K3')).json.id;
  expectStatus(await api('POST', `/v1/rooms/${kroom}/kick`, 'K1', { userId: k3id }), 409, 'nobody can be removed after the start');
  sK2.close();

  const expiryLobby = (await api('POST', '/v1/rooms', 'K1', {})).json.code as string;
  const sK1 = await sock('K1');
  await ack(sK1, 'room:subscribe', { code: expiryLobby });
  const closedMsgs: any[] = [];
  sK1.on('room:closed', (e) => closedMsgs.push(e));
  await sweepOnce();
  assert.equal((await pool.query('SELECT 1 FROM rooms WHERE code = $1', [expiryLobby])).rows.length, 1, 'a fresh expiryLobby stays');
  await pool.query(`UPDATE rooms SET created_at = NOW() - INTERVAL '2 hours' WHERE code = $1`, [expiryLobby]);
  const expired = await sweepOnce();
  assert.ok(expired.rooms >= 1);
  assert.equal((await pool.query('SELECT 1 FROM rooms WHERE code = $1', [expiryLobby])).rows.length, 0);
  await new Promise((r) => setTimeout(r, 200));
  assert.equal(closedMsgs.length, 1);
  pass('a lobby nobody started closes after the expiry time and players are told');
  sK1.close();
  sCD.close(); sCE.close();

  // ---- match XP
  const progBefore = (await api('GET', '/v1/me/progress', 'FA')).json;
  assert.equal(progBefore.xp, 0);
  const fbProg = (await api('GET', '/v1/me/progress', 'FB')).json;
  assert.equal(fbProg.wins, 1, 'the forfeit winner was rewarded');
  assert.equal(fbProg.xp, 30);
  assert.equal(fbProg.level, 1);
  pass('the winner of a forfeited game earns XP; the leaver earns none');
  // finish a fresh game by hand and check idempotence + cap
  for (const n of ['XA', 'XB']) await api('POST', '/v1/auth/guest', n, {});
  const xr = await startedRoom('XA', ['XB'], 'connect4');
  const sXA = await sock('XA'); const sXB = await sock('XB');
  await ack(sXA, 'room:subscribe', { code: xr.code }); await ack(sXB, 'room:subscribe', { code: xr.code });
  const seq: [any, number][] = [[sXA, 0], [sXB, 1], [sXA, 0], [sXB, 1], [sXA, 0], [sXB, 1], [sXA, 0]];
  for (const [s, c] of seq) assert.equal((await ack(s, 'game:move', { code: xr.code, move: { column: c } })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  const xa = (await api('GET', '/v1/me/progress', 'XA')).json;
  const xb = (await api('GET', '/v1/me/progress', 'XB')).json;
  assert.deepEqual([xa.xp, xa.wins, xa.played], [30, 1, 1]);
  assert.deepEqual([xb.xp, xb.wins, xb.played], [10, 0, 1]);
  pass('a finished game pays 30 XP to the winner and 10 to the other player');
  assert.ok((await ack(sXA, 'game:move', { code: xr.code, move: { column: 0 } })).error);
  assert.equal((await api('GET', '/v1/me/progress', 'XA')).json.xp, 30, 'nothing more after the game ended');
  assert.ok(JSON.stringify((await api('GET', '/v1/me/export', 'XA')).json.xp).includes('win'));
  pass('XP is paid once and appears in the data export');
  sXA.close(); sXB.close();

  // ---- Party Mode
  for (const n of ['PA', 'PB']) await api('POST', '/v1/auth/guest', n, {});
  const pa = (await api('GET', '/v1/me', 'PA')).json.id as string;
  const pb = (await api('GET', '/v1/me', 'PB')).json.id as string;
  expectStatus(await api('POST', '/v1/rooms', 'PA', { party: true, rounds: 1 }), 400, 'too few rounds');
  expectStatus(await api('POST', '/v1/rooms', 'PA', { party: true, rounds: 99 }), 400, 'too many rounds');
  expectStatus(await api('POST', '/v1/rooms', 'PA', { party: true, gameType: 'ludo' }), 400, 'a party picks its own games');
  const partyRoom = await api('POST', '/v1/rooms', 'PA', { party: true, rounds: 2 });
  assert.equal(partyRoom.status, 201);
  assert.equal(partyRoom.json.party.rounds, 2);
  assert.equal(partyRoom.json.party.round, 0);
  const pcode = partyRoom.json.code as string;
  await api('POST', '/v1/rooms/join', 'PB', { code: pcode });
  for (const w of ['PA', 'PB']) await api('POST', `/v1/rooms/${pcode}/ready`, w, { ready: true });
  const pstart = await api('POST', `/v1/rooms/${pcode}/start`, 'PA');
  assert.equal(pstart.status, 200, JSON.stringify(pstart.json));
  assert.equal(pstart.json.party.round, 1);
  assert.ok(['snl', 'ludo', 'connect4', 'wordrush'].includes(pstart.json.gameType));
  assert.ok(pstart.json.gameState.players.length === 2);
  pass('a party room starts with a randomly chosen game');

  // Make round 1 a Connect Four game we can finish deterministically.
  const { connect4 } = await import('../src/games/connect4');
  const forceConnect4 = async () => {
    const cur = (await pool.query('SELECT game_state FROM rooms WHERE code = $1', [pcode])).rows[0].game_state;
    await pool.query(`UPDATE rooms SET game_type = 'connect4', game_state = $2, status = 'playing' WHERE code = $1`,
      [pcode, JSON.stringify(connect4.init([pa, pb], Date.now(), cur.version + 1))]);
  };
  await forceConnect4();
  const sPA = await sock('PA'); const sPB = await sock('PB');
  await ack(sPA, 'room:subscribe', { code: pcode }); await ack(sPB, 'room:subscribe', { code: pcode });
  const playOut = async () => {
    for (const [s, c] of [[sPA, 0], [sPB, 1], [sPA, 0], [sPB, 1], [sPA, 0], [sPB, 1], [sPA, 0]] as [any, number][])
      assert.equal((await ack(s, 'game:move', { code: pcode, move: { column: c } })).success, true);
  };
  const updates: any[] = [];
  sPB.on('room:updated', (e) => updates.push(e));
  assert.ok((await ack(sPA, 'game:rematch', { code: pcode })).error, 'next round only after the game ends');
  await playOut();
  await new Promise((r) => setTimeout(r, 250));
  let pr = (await pool.query('SELECT party, status FROM rooms WHERE code = $1', [pcode])).rows[0];
  assert.deepEqual(pr.party.scores, { [pa]: 3, [pb]: 1 });
  assert.equal(pr.party.finished, false);
  assert.equal(updates.at(-1)?.party.scores[pa], 3, 'players are told the new score');
  pass('finishing a round scores it and tells everyone');

  const startedMsgs: any[] = [];
  sPB.on('room:started', (e) => startedMsgs.push(e));
  assert.equal((await ack(sPB, 'game:rematch', { code: pcode })).success, true);
  await new Promise((r) => setTimeout(r, 250));
  pr = (await pool.query('SELECT party, status, game_type FROM rooms WHERE code = $1', [pcode])).rows[0];
  assert.equal(pr.party.round, 2);
  assert.equal(pr.status, 'playing');
  assert.notEqual(pr.game_type, 'connect4', 'a different game than the round just played');
  assert.equal(startedMsgs.at(-1).party.round, 2, 'players are sent to the next round');
  pass('the next round brings a different random game');

  await forceConnect4();
  await playOut();
  await new Promise((r) => setTimeout(r, 250));
  pr = (await pool.query('SELECT party FROM rooms WHERE code = $1', [pcode])).rows[0];
  assert.deepEqual(pr.party.scores, { [pa]: 6, [pb]: 2 });
  assert.equal(pr.party.finished, true);
  assert.equal(pr.party.history.length, 2);
  assert.ok((await ack(sPA, 'game:rematch', { code: pcode })).error, 'no round after the last');
  pass('the party ends after the last round with final scores');
  sPA.close(); sPB.close();

  // ---- Word Rush and Bluff & Vote over real sockets
  for (const n of ['WA', 'WB', 'WC']) await api('POST', '/v1/auth/guest', n, {});
  const wids: Record<string, string> = {};
  for (const n of ['WA', 'WB', 'WC']) wids[n] = (await api('GET', '/v1/me', n)).json.id;
  const noSecrets = (o: unknown) => assert.ok(!/"_[A-Za-z]/.test(JSON.stringify(o)), 'a secret field leaked: ' + JSON.stringify(o).slice(0, 200));

  // Word Rush
  const wr = await startedRoom('WA', ['WB'], 'wordrush');
  noSecrets(wr.room);
  const sWA = await sock('WA'); const sWB = await sock('WB');
  const wrSeen: any[] = [];
  sWB.on('game:state', (e) => wrSeen.push(e));
  const subA = await ack(sWA, 'room:subscribe', { code: wr.code });
  noSecrets(subA); await ack(sWB, 'room:subscribe', { code: wr.code });
  noSecrets((await api('GET', `/v1/rooms/${wr.code}`, 'WB')).json);
  const answer = (await pool.query('SELECT game_state FROM rooms WHERE code = $1', [wr.code])).rows[0].game_state._word as string;
  const miss = await ack(sWA, 'game:move', { code: wr.code, move: { guess: 'zzzzzz' } });
  assert.equal(miss.success, true); noSecrets(miss);
  const hit = await ack(sWB, 'game:move', { code: wr.code, move: { guess: answer } });
  assert.equal(hit.success, true); noSecrets(hit);
  await new Promise((r) => setTimeout(r, 200));
  noSecrets(wrSeen);
  assert.equal(wrSeen.at(-1).state.scores[wids.WB], 3);
  assert.equal(wrSeen.at(-1).state.last.word, answer, 'the word is shown once the round is over');
  assert.equal(wrSeen.at(-1).state.round, 2);
  pass('Word Rush: the word never leaves the server until the round is over');
  const qm = await ack(sWA, 'match:join', { gameType: 'bluff' });
  assert.equal(qm.code, 'PRIVATE_ONLY');
  pass('Bluff & Vote cannot be matched with strangers');
  sWA.close(); sWB.close();

  // Bluff & Vote with three friends
  const bl = await startedRoom('WA', ['WB', 'WC'], 'bluff');
  noSecrets(bl.room);
  const bs: Record<string, any> = {};
  for (const n of ['WA', 'WB', 'WC']) { bs[n] = await sock(n); await ack(bs[n], 'room:subscribe', { code: bl.code }); }
  const seenByC: any[] = [];
  bs.WC.on('game:state', (e: any) => seenByC.push(e));
  expectStatus(await api('POST', '/v1/rooms', 'WA', { gameType: 'bluff', maxPlayers: 2 }), 400, 'Bluff needs at least 3');
  for (const [n, t] of [['WA', 'Fake A'], ['WB', 'Fake B']]) assert.equal((await ack(bs[n], 'game:move', { code: bl.code, move: { answer: t } })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  noSecrets(seenByC);
  assert.ok(!JSON.stringify(seenByC).includes('Fake A'), 'fakes are not shown while writing');
  assert.deepEqual(seenByC.at(-1).state.submitted.length, 2);
  const truthText = (await pool.query('SELECT game_state FROM rooms WHERE code = $1', [bl.code])).rows[0].game_state._truth as string;
  assert.ok((await ack(bs.WC, 'game:move', { code: bl.code, move: { answer: truthText } })).error, 'the real answer is refused');
  assert.equal((await ack(bs.WC, 'game:move', { code: bl.code, move: { answer: 'Fake C' } })).success, true);
  await new Promise((r) => setTimeout(r, 200));
  const voting = seenByC.at(-1).state;
  assert.equal(voting.phase, 'vote');
  assert.equal(voting.options.length, 4);
  noSecrets(voting);
  assert.ok(!JSON.stringify(voting).includes('authors'), 'who wrote what is hidden while voting');
  const optId = (t: string) => voting.options.find((o: any) => o.text === t).id;
  await ack(bs.WA, 'game:move', { code: bl.code, move: { option: optId(truthText) } });
  await ack(bs.WB, 'game:move', { code: bl.code, move: { option: optId(truthText) } });
  await ack(bs.WC, 'game:move', { code: bl.code, move: { option: optId('Fake A') } });
  await new Promise((r) => setTimeout(r, 200));
  const rev = seenByC.at(-1).state;
  noSecrets(rev);
  assert.equal(rev.phase, 'reveal');
  assert.deepEqual(rev.reveal.gained, { [wids.WA]: 3, [wids.WB]: 2, [wids.WC]: 0 });
  assert.deepEqual(rev.reveal.authors[optId('Fake A')], [wids.WA]);
  pass('Bluff & Vote: hidden while writing and voting, revealed with scores afterwards');
  Object.values(bs).forEach((x: any) => x.close());

  // ---- account deletion
  const ids2: Record<string, string> = {};
  for (const n of ['E', 'F', 'G', 'H', 'I']) {
    ids2[n] = (await api('POST', '/v1/auth/guest', n, {})).json.id;
  }
  const lobby = await api('POST', '/v1/rooms', 'E', {});
  await api('POST', '/v1/rooms/join', 'F', { code: lobby.json.code });
  expectStatus(await api('POST', '/v1/me/delete', 'E', {}), 400, 'deletion requires explicit confirmation');
  expectStatus(await api('POST', '/v1/me/delete', 'E', { confirm: true }), 200, 'E deletes their account');
  assert.deepEqual(deletedFirebaseUsers, [uidOf('E')]);
  pass('Firebase user deletion was requested');
  expectStatus(await api('GET', '/v1/me', 'E'), 404, 'deleted account no longer has a profile');
  const stillThere = await api('GET', `/v1/rooms/${lobby.json.code}`, 'F');
  assert.equal(stillThere.json.hostUserId, ids2.F);
  assert.equal(stillThere.json.players.length, 1);
  pass('room survives; F became host');

  const g1 = await startedRoom('G', ['H']);
  expectStatus(await api('POST', '/v1/reports', 'H', { userId: ids2.G, reason: 'spam' }), 201, 'H reports G');
  expectStatus(await api('POST', '/v1/me/delete', 'H', { confirm: true }), 200, 'reporter H deletes their account');
  const kept = await pool.query('SELECT reporter_id, reported_id FROM reports WHERE reported_id = $1', [ids2.G]);
  assert.equal(kept.rows.length, 1);
  assert.equal(kept.rows[0].reporter_id, null);
  pass('report is kept with the reporter anonymised');
  assert.equal((await pool.query('SELECT 1 FROM recent_players WHERE user_id = $1 OR other_id = $1', [ids2.H])).rows.length, 0);
  pass('deleted user left no social rows behind');
  void g1;

  // ---- admin API
  expectStatus(await admin('GET', '/admin/reports', undefined, null), 401, 'admin API refuses requests without a token');
  expectStatus(await admin('GET', '/admin/reports', undefined, 'wrong-token-1234567890xx'), 401, 'admin API refuses a wrong token');
  const open = await admin('GET', '/admin/reports');
  assert.equal(open.status, 200);
  const mine = open.json.reports.find((r: any) => r.reported_id === ids2.G);
  assert.ok(mine && mine.reporter_nickname === null && mine.reports_against >= 1);
  const harass = open.json.reports.find((r: any) => r.reason === 'harassment');
  assert.equal(harass.reporter_nickname !== null, true);
  pass('admin lists open reports with nicknames');
  expectStatus(await admin('POST', `/admin/reports/${mine.id}/resolve`, { status: 'bogus' }), 400, 'invalid resolution rejected');
  expectStatus(await admin('POST', `/admin/reports/${mine.id}/resolve`, { status: 'actioned' }), 200, 'report resolved');
  assert.ok(!(await admin('GET', '/admin/reports')).json.reports.some((r: any) => r.id === mine.id));

  // ---- suspension
  const g2 = await startedRoom('G', ['I']);
  const sg = await sock('G');
  assert.equal((await ack(sg, 'room:subscribe', { code: g2.code })).success, true);
  expectStatus(await admin('POST', `/admin/users/${ids2.G}/ban`), 200, 'G is suspended');
  expectStatus(await api('GET', '/v1/me', 'G'), 403, 'suspended user is refused over REST');
  assert.match((await ack(sg, 'game:roll', { code: g2.code })).message, /suspended/);
  pass('already-connected suspended user cannot act');
  await assert.rejects(sock('G'));
  pass('suspended user cannot open a new socket');
  sg.close();
  expectStatus(await admin('POST', `/admin/users/${ids2.G}/unban`), 200, 'G is restored');
  expectStatus(await api('GET', '/v1/me', 'G'), 200, 'restored user can use the API again');
  // ---- product events
  await new Promise((r) => setTimeout(r, 400)); // events are written without waiting
  const names = new Set((await pool.query('SELECT DISTINCT name FROM events')).rows.map((r: any) => r.name));
  for (const n of ['game_started', 'game_finished', 'rematch_started', 'match_searching', 'match_found',
    'match_timeout', 'match_cancelled', 'friend_request_sent', 'friend_request_accepted']) {
    assert.ok(names.has(n), `event ${n} was recorded`);
  }
  pass('the core-loop events were recorded by the real flows');
  const sources = new Set((await pool.query(
    `SELECT DISTINCT props->>'source' AS s FROM events WHERE name = 'game_started'`)).rows.map((r: any) => r.s));
  assert.ok(sources.has('room') && sources.has('quick_match'));
  const pii = await pool.query(`SELECT COUNT(*)::int AS n FROM events WHERE props ?| ARRAY['nickname','name','email','message','text']`);
  assert.equal(pii.rows[0].n, 0);
  pass('events carry no names or text');

  expectStatus(await admin('GET', '/admin/stats', undefined, null), 401, 'stats need the admin token');
  expectStatus(await admin('GET', '/admin/stats?days=0'), 400, 'stats reject a bad window');
  const stats = await admin('GET', '/admin/stats?days=7');
  assert.equal(stats.status, 200);
  const started = stats.json.events.find((e: any) => e.name === 'game_started');
  assert.ok(started.events >= 3 && started.users >= 2);
  assert.ok(stats.json.byGame.some((g: any) => g.game === 'connect4' && g.name === 'game_finished'));
  pass('admin stats return plain counts, overall and per game');

  // deleting an account detaches its events instead of keeping them linked
  const before = (await pool.query('SELECT COUNT(*)::int AS n FROM events')).rows[0].n;
  assert.ok((await pool.query('SELECT COUNT(*)::int AS n FROM events WHERE user_id = $1', [ids4.M])).rows[0].n > 0);
  expectStatus(await api('POST', '/v1/me/delete', 'M', { confirm: true }), 200, 'M deletes their account');
  assert.equal((await pool.query('SELECT COUNT(*)::int AS n FROM events WHERE user_id = $1', [ids4.M])).rows[0].n, 0);
  assert.equal((await pool.query('SELECT COUNT(*)::int AS n FROM events')).rows[0].n, before, 'rows are kept, just anonymous');
  pass('deleting an account makes its events anonymous');

  // retention: old rows go, recent ones stay
  await pool.query(`INSERT INTO events (name, created_at) VALUES ('old_test', NOW() - INTERVAL '200 days'), ('new_test', NOW())`);
  assert.ok((await purgeOldEvents()) >= 1);
  const left = new Set((await pool.query(`SELECT name FROM events WHERE name IN ('old_test','new_test')`)).rows.map((r: any) => r.name));
  assert.ok(!left.has('old_test') && left.has('new_test'));
  pass('events older than the retention window are purged');

  console.log('\nALL INTEGRATION CHECKS PASSED');
  process.exit(0);
}

main().catch((e) => { console.error('FAIL:', e); process.exit(1); });
