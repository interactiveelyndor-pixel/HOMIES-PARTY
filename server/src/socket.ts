import { publicState } from './games/types';
import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { firebaseAuth } from './firebase';
import { pool } from './db';
import { getRoomDetailsById, createMatchedRoom, DbUser, RoomResponse } from './rooms';
import { Matchmaker } from './matchmaking';
import { limiter } from './ratelimit';
import { logEvent } from './events';
import { getGame } from './games/registry';
import { BaseState, GameModule, GameResult } from './games/types';
import { ActionOptions, runGameAction } from './gameRuntime';
import { getFlags } from './flags';
import { getEligibility } from './eligibility';
import { markConnected, markDisconnected, socketIdsOf } from './presence';
import { randomInt } from 'crypto';

export let io: SocketIOServer | null = null;

/** The only reactions players can send: a fixed set, so there is no free text to moderate. */
export const REACTIONS = ['👍', '😂', '😮', '🔥', '👏', '😢'];

/** Quick phrases: also a fixed set. Mirrors lib/screens/online_reactions.dart. */
export const PHRASES = ['Good luck!', 'Well played!', 'Nooo!', 'Nice move!', 'Hahaha!', 'Oops!'];
const SENDABLE = new Set([...REACTIONS, ...PHRASES]);

export function emitToRoom(roomCode: string, event: string, payload: unknown): void {
  io?.to(roomCode.toUpperCase()).emit(event, payload);
}

/** Sends to every open socket of a user (they may have the app open twice). */
export function emitToUser(userId: string, event: string, payload: unknown): void {
  for (const id of socketIdsOf(userId)) io?.to(id).emit(event, payload);
}

/** Stops a user's sockets receiving a room's broadcasts (after a kick). */
export function leaveRoomChannel(userId: string, roomCode: string): void {
  for (const id of socketIdsOf(userId)) io?.in(id).socketsLeave(roomCode.toUpperCase());
}

export function broadcastRoomUpdated(roomCode: string, room: RoomResponse): void {
  if (io) {
    io.to(roomCode.toUpperCase()).emit('room:updated', room);
  }
}

export function broadcastRoomStarted(roomCode: string, room: RoomResponse): void {
  if (io) {
    io.to(roomCode.toUpperCase()).emit('room:started', room);
  }
}

export function broadcastGameState(roomCode: string, state: BaseState): void {
  if (io) {
    io.to(roomCode.toUpperCase()).emit('game:state', { code: roomCode.toUpperCase(), state: publicState(state) });
  }
}

export function setupSocketIO(httpServer: HttpServer): SocketIOServer {
  io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });
  const server = io;

  const matchmaker = new Matchmaker(
    {
      isBlocked: async (a, b) =>
        (
          await pool.query(
            `SELECT 1 FROM blocks
             WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1) LIMIT 1`,
            [a, b]
          )
        ).rows.length > 0,
      createRoom: async (gameType, userIds) => {
        const room = await createMatchedRoom(gameType, userIds);
        logEvent('match_found', userIds[0], { gameType, players: userIds.length });
        return room;
      },
      send: (socketId, event, payload) => {
        if (event === 'match:timeout') {
          const who = (server.sockets.sockets.get(socketId)?.data as any)?.user?.id ?? null;
          logEvent('match_timeout', who, (payload as any) ?? {});
        }
        server.to(socketId).emit(event, payload);
      },
      isConnected: (socketId) => server.sockets.sockets.has(socketId),
      matched: (room, socketIds) => {
        const code = (room as RoomResponse).code.toUpperCase();
        socketIds.forEach((id) => server.sockets.sockets.get(id)?.join(code));
      },
    },
    {
      timeoutMs: Number(process.env.MATCH_TIMEOUT_MS) || 60_000,
      playersFor: (gameType) => getGame(gameType)?.minPlayers ?? 2,
    }
  );

  // Authentication middleware: verify Firebase token in handshake.auth.token
  io.use(async (socket: Socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token || typeof token !== 'string') {
        return next(new Error('Authentication token is missing.'));
      }

      let decoded;
      try {
        decoded = await firebaseAuth.verifyIdToken(token);
      } catch (err: any) {
        return next(new Error('Invalid or expired authentication token.'));
      }

      // Check if user exists in database
      const userRes = await pool.query(
        'SELECT id, firebase_uid, nickname, avatar, created_at, banned_at FROM users WHERE firebase_uid = $1',
        [decoded.uid]
      );

      if (userRes.rows.length === 0) {
        return next(new Error('User profile not found. Please register as guest first.'));
      }
      if (userRes.rows[0].banned_at) {
        return next(new Error('This account has been suspended.'));
      }

      socket.data.user = userRes.rows[0] as DbUser;
      return next();
    } catch (err: any) {
      return next(new Error('Authentication failed.'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const user = socket.data.user as DbUser;
    markConnected(user.id, socket.id);

    // Event: room:subscribe
    socket.on('room:subscribe', async (data: any, callback?: (res: any) => void) => {
      try {
        const code = typeof data?.code === 'string' ? data.code.trim().toUpperCase() : '';
        if (!code) {
          if (typeof callback === 'function') {
            callback({ error: 'Bad Request', message: 'Room code is required.' });
          }
          return;
        }

        // Check if room exists
        const roomRes = await pool.query(
          'SELECT id, code FROM rooms WHERE UPPER(code) = $1',
          [code]
        );

        if (roomRes.rows.length === 0) {
          if (typeof callback === 'function') {
            callback({ error: 'Not Found', message: 'Room not found.' });
          }
          return;
        }

        const room = roomRes.rows[0];

        // Check if user is a member of that room
        const memberRes = await pool.query(
          'SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2',
          [room.id, user.id]
        );

        if (memberRes.rows.length === 0) {
          if (typeof callback === 'function') {
            callback({ error: 'Forbidden', message: 'You are not a member of this room.' });
          }
          return;
        }

        // Join the Socket.IO room named for that code
        socket.join(room.code.toUpperCase());

        // Send current room state in acknowledgement
        const roomDetails = await getRoomDetailsById(room.id);
        if (typeof callback === 'function') {
          callback({
            success: true,
            room: roomDetails,
            ...roomDetails,
          });
        }
      } catch (err: any) {
        if (typeof callback === 'function') {
          callback({ error: 'Internal Server Error', message: 'Failed to subscribe to room.' });
        }
      }
    });

    // Every game action goes through runGameAction (see gameRuntime.ts), the same
    // locked transaction the server's own timers use.
    const gameAction = (
      event: string,
      compute: (data: any) => ActionOptions['compute']
    ) => {
      socket.on(event, async (data: any, callback?: (res: any) => void) => {
        const reply = (res: any) => { if (typeof callback === 'function') callback(res); };
        const out = await runGameAction({
          code: typeof data?.code === 'string' ? data.code : '',
          actorId: user.id,
          event,
          expectedRevision: data?.expectedRevision,
          compute: compute(data),
        });
        if (!out.ok) return reply({ error: out.error, message: out.message, code: out.code });
        reply({ success: true, state: publicState(out.state) });
      });
    };

    const playing = (room: any): GameResult<BaseState> | null =>
      room.status === 'playing' ? null : { error: 'The game is not in progress.' };

    const doMove = (input: unknown): ActionOptions['compute'] =>
      (mod: GameModule<BaseState>, room: any, active: string[], now: number): GameResult<BaseState> =>
        playing(room) ??
        mod.move(room.game_state, user.id, input, {
          active: new Set(active),
          now,
          randomInt: (min, max) => randomInt(min, max),
        });

    // Move with a client-supplied input (e.g. { column: 3 } in Connect Four).
    gameAction('game:move', (data) => doMove(data?.move));

    // Older name for a move that carries no input (Snakes & Ladders: the server rolls).
    gameAction('game:roll', () => doMove(undefined));

    // Any member may report that the current turn ran past its deadline; the server checks.
    gameAction('game:skip', () => (mod, room, active, now) =>
      playing(room) ?? mod.skip(room.game_state, new Set(active), now));

    // Any member may start a rematch once the game is finished.
    gameAction('game:rematch', () => (mod, room, active, now) =>
      room.status !== 'finished'
        ? { error: 'A rematch is only possible after the game ends.' }
        : active.length < mod.minPlayers || active.length > mod.maxPlayers
        ? { error: `This game needs ${mod.minPlayers}-${mod.maxPlayers} players for a rematch.` }
        : { state: mod.init(active, now, (room.game_state as BaseState).version + 1) });

    // Reactions: a fixed emoji shown to the other players in the room.
    socket.on('game:react', async (data: any, callback?: (res: any) => void) => {
      const reply = (res: any) => { if (typeof callback === 'function') callback(res); };
      try {
        const code = typeof data?.code === 'string' ? data.code.trim().toUpperCase() : '';
        const emoji = data?.emoji;
        if (!code || typeof emoji !== 'string' || !SENDABLE.has(emoji)) {
          return reply({ error: 'Bad Request', message: 'Unknown reaction.' });
        }
        if (!limiter.allow(`react:${user.id}`, 20, 30_000)) {
          return reply({ error: 'Too Many Requests', message: 'Slow down a little.' });
        }
        const allowed = await pool.query(
          `SELECT 1 FROM room_players rp
           JOIN rooms r ON r.id = rp.room_id
           JOIN users u ON u.id = rp.user_id
           WHERE UPPER(r.code) = $1 AND rp.user_id = $2 AND u.banned_at IS NULL`,
          [code, user.id]
        );
        if (!allowed.rows.length) {
          return reply({ error: 'Forbidden', message: 'You are not a member of this room.' });
        }
        // Anyone who blocked the sender never sees their reactions.
        const blockers = new Set<string>(
          (await pool.query('SELECT blocker_id FROM blocks WHERE blocked_id = $1', [user.id])).rows.map(
            (r: any) => r.blocker_id
          )
        );
        const payload = { code, userId: user.id, emoji, at: Date.now() };
        for (const s of await server.in(code).fetchSockets()) {
          if (!blockers.has((s.data as any).user?.id)) s.emit('game:reaction', payload);
        }
        reply({ success: true });
      } catch (err: any) {
        reply({ error: 'Internal Server Error', message: 'Could not send the reaction.' });
      }
    });

    // Quick Match: wait for another player who picked the same game.
    socket.on('match:join', async (data: any, callback?: (res: any) => void) => {
      const reply = (res: any) => { if (typeof callback === 'function') callback(res); };
      try {
        const gameType = typeof data?.gameType === 'string' ? data.gameType : '';
        if (!getGame(gameType)) {
          return reply({ error: 'Bad Request', message: 'Unknown game.' });
        }
        if (getGame(gameType)!.privateOnly) {
          return reply({ error: 'Bad Request', code: 'PRIVATE_ONLY', message: 'This game is played in private rooms with friends.' });
        }
        if (!(await getFlags()).publicDiscovery) {
          return reply({ error: 'Forbidden', code: 'FEATURE_DISABLED', message: 'Quick Match is not available right now.' });
        }
        const elig = await getEligibility(user.id);
        if (!elig.social) {
          return reply({
            error: 'Forbidden',
            code: elig.consented ? 'SOCIAL_NOT_ALLOWED' : 'CONSENT_REQUIRED',
            message: elig.consented
              ? 'Quick Match is not available for your age range.'
              : 'Please accept the terms and tell us your age range first.',
          });
        }
        if (!limiter.allow(`match:${user.id}`, 12, 60_000)) {
          return reply({ error: 'Too Many Requests', message: 'Please wait a moment before searching again.' });
        }
        const banned = await pool.query('SELECT 1 FROM users WHERE id = $1 AND banned_at IS NOT NULL', [user.id]);
        if (banned.rows.length) {
          return reply({ error: 'Forbidden', message: 'This account has been suspended.' });
        }
        const joined = await matchmaker.join(user.id, socket.id, gameType);
        if (joined.status === 'searching') logEvent('match_searching', user.id, { gameType });
        reply({ success: true, ...joined });
      } catch (err: any) {
        reply({ error: 'Internal Server Error', message: 'Could not start matchmaking.' });
      }
    });

    socket.on('match:cancel', (_data: any, callback?: (res: any) => void) => {
      const wasWaiting = matchmaker.cancel(user.id);
      if (wasWaiting) logEvent('match_cancelled', user.id);
      if (typeof callback === 'function') callback({ success: true, wasWaiting });
    });

    // Event: room:unsubscribe
    socket.on('room:unsubscribe', (data: any, callback?: (res: any) => void) => {
      const code = typeof data?.code === 'string' ? data.code.trim().toUpperCase() : '';
      if (code) {
        socket.leave(code);
      }
      if (typeof callback === 'function') {
        callback({ success: true });
      }
    });

    // Clean up on disconnect
    socket.on('disconnect', () => {
      // Socket.IO leaves all joined rooms automatically; stop any search.
      matchmaker.disconnect(socket.id);
      markDisconnected(user.id, socket.id);
    });
  });

  return io;
}
