import { publicState } from './games/types';
import { PartyState, newParty, pickGame, PARTY_DEFAULT_ROUNDS, PARTY_MAX_PLAYERS, PARTY_MAX_ROUNDS, PARTY_MIN_ROUNDS } from './party';
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { Pool, PoolClient } from 'pg';
import { pool } from './db';
import { authenticate } from './auth';
import { broadcastRoomUpdated, broadcastRoomStarted, emitToUser, leaveRoomChannel } from './socket';
import { GAME_IDS, getGame } from './games/registry';
import { logEvent } from './events';
import { requireOnline } from './eligibility';
import { isUuid } from './ratelimit';

// Games the server can run authoritatively.
const SUPPORTED_GAMES = GAME_IDS;

// 32-character set: A-Z and 2-9, excluding O, I, 0, 1
const ROOM_CODE_CHARSET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function generateRoomCode(): string {
  let code = '';
  for (let i = 0; i < 6; i++) {
    const randomIndex = Math.floor(Math.random() * ROOM_CODE_CHARSET.length);
    code += ROOM_CODE_CHARSET[randomIndex];
  }
  return code;
}

export interface DbUser {
  id: string;
  firebase_uid: string;
  nickname: string;
  avatar: string | null;
  created_at: string;
  banned_at?: string | null;
}

export interface RoomPlayerResponse {
  id: string;
  userId: string;
  user_id: string;
  nickname: string;
  avatar: string | null;
  isReady: boolean;
  is_ready: boolean;
  isHost: boolean;
  is_host: boolean;
  joinedAt: string;
  joined_at: string;
}

export interface RoomResponse {
  id: string;
  code: string;
  hostUserId: string;
  host_user_id: string;
  status: string;
  maxPlayers: number;
  max_players: number;
  createdAt: string;
  created_at: string;
  gameType: string;
  gameState: unknown | null;
  /** Present for Party Mode rooms: rounds, scores, history. */
  party: unknown | null;
  players: RoomPlayerResponse[];
}

export async function getDbUser(request: FastifyRequest, reply: FastifyReply): Promise<DbUser | null> {
  const uid = request.firebaseUser?.uid;
  if (!uid) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Authentication token missing or invalid.',
    });
    return null;
  }

  const userRes = await pool.query(
    'SELECT id, firebase_uid, nickname, avatar, created_at, banned_at FROM users WHERE firebase_uid = $1',
    [uid]
  );

  if (userRes.rows.length === 0) {
    await reply.status(404).send({
      error: 'Not Found',
      message: 'User profile not found. Please register as guest first.',
    });
    return null;
  }

  if (userRes.rows[0].banned_at) {
    await reply.status(403).send({
      error: 'Forbidden',
      message: 'This account has been suspended.',
    });
    return null;
  }

  return userRes.rows[0];
}

export async function getRoomDetailsById(
  roomId: string,
  clientOrPool: Pool | PoolClient = pool
): Promise<RoomResponse | null> {
  const query = `
    SELECT
      r.id AS room_id,
      r.code,
      r.host_user_id,
      r.status,
      r.max_players,
      r.game_type,
      r.game_state,
      r.party,
      r.created_at AS room_created_at,
      rp.user_id,
      rp.is_ready,
      rp.joined_at,
      u.nickname,
      u.avatar
    FROM rooms r
    LEFT JOIN room_players rp ON rp.room_id = r.id
    LEFT JOIN users u ON u.id = rp.user_id
    WHERE r.id = $1
    ORDER BY rp.joined_at ASC
  `;

  const res = await clientOrPool.query(query, [roomId]);
  if (res.rows.length === 0) return null;

  const first = res.rows[0];
  const players: RoomPlayerResponse[] = res.rows
    .filter((row: any) => row.user_id !== null)
    .map((row: any) => ({
      id: row.user_id,
      userId: row.user_id,
      user_id: row.user_id,
      nickname: row.nickname || 'Unknown Player',
      avatar: row.avatar,
      isReady: row.is_ready,
      is_ready: row.is_ready,
      isHost: row.user_id === first.host_user_id,
      is_host: row.user_id === first.host_user_id,
      joinedAt: row.joined_at,
      joined_at: row.joined_at,
    }));

  return {
    id: first.room_id,
    code: first.code,
    hostUserId: first.host_user_id,
    host_user_id: first.host_user_id,
    status: first.status,
    maxPlayers: first.max_players,
    max_players: first.max_players,
    createdAt: first.room_created_at,
    created_at: first.room_created_at,
    gameType: first.game_type,
    gameState: publicState(first.game_state),
    party: first.party ?? null,
    players,
  };
}

/**
 * Creates a room that is already playing, for players Quick Match paired up.
 * Everyone is ready; the first user is the host. Players who share a started
 * game become each other's recent players, as with a normal start.
 */
export async function createMatchedRoom(gameType: string, userIds: string[]): Promise<RoomResponse> {
  const game = getGame(gameType);
  if (!game || userIds.length < game.minPlayers || userIds.length > game.maxPlayers) {
    throw new Error(`Cannot create a ${gameType} room for ${userIds.length} players.`);
  }
  const client = await pool.connect();
  try {
    for (let attempt = 0; attempt < 10; attempt++) {
      try {
        await client.query('BEGIN');
        const room = await client.query(
          `INSERT INTO rooms (code, host_user_id, status, max_players, game_type, game_state)
           VALUES ($1, $2, 'playing', $3, $4, $5) RETURNING id`,
          [generateRoomCode(), userIds[0], userIds.length, gameType, JSON.stringify(game.init(userIds, Date.now()))]
        );
        const roomId = room.rows[0].id;
        for (const id of userIds) {
          await client.query('INSERT INTO room_players (room_id, user_id, is_ready) VALUES ($1, $2, true)', [roomId, id]);
        }
        await client.query(
          `INSERT INTO recent_players (user_id, other_id, last_played_at)
           SELECT a.user_id, b.user_id, NOW()
           FROM room_players a JOIN room_players b ON a.room_id = b.room_id AND a.user_id <> b.user_id
           WHERE a.room_id = $1
           ON CONFLICT (user_id, other_id) DO UPDATE SET last_played_at = NOW()`,
          [roomId]
        );
        await client.query('COMMIT');
        logEvent('game_started', userIds[0], { gameType, players: userIds.length, source: 'quick_match' });
        return (await getRoomDetailsById(roomId))!;
      } catch (err: any) {
        await client.query('ROLLBACK').catch(() => {});
        if (err.code === '23505' && err.constraint === 'rooms_code_key') continue; // code collision
        throw err;
      }
    }
    throw new Error('Could not generate a unique room code.');
  } finally {
    client.release();
  }
}

export async function roomRoutes(server: FastifyInstance): Promise<void> {
  // 1. POST /v1/rooms - Create a room
  server.post('/v1/rooms', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      if (!(await requireOnline(user.id, reply))) return;

      const body = request.body as any;
      let maxPlayers = 4;
      let gameType = 'snl';
      let party: PartyState | null = null;

      if (body !== undefined && body !== null) {
        if (typeof body !== 'object' || Array.isArray(body)) {
          return reply.status(400).send({
            error: 'Bad Request',
            message: 'Request body must be a JSON object.',
          });
        }

        if (body.maxPlayers !== undefined) {
          if (
            typeof body.maxPlayers !== 'number' ||
            !Number.isInteger(body.maxPlayers) ||
            body.maxPlayers < 2 ||
            body.maxPlayers > 4
          ) {
            return reply.status(400).send({
              error: 'Bad Request',
              message: 'maxPlayers must be an integer between 2 and 4.',
            });
          }
          maxPlayers = body.maxPlayers;
        }

        if (body.gameType !== undefined) {
          if (typeof body.gameType !== 'string' || !SUPPORTED_GAMES.includes(body.gameType)) {
            return reply.status(400).send({
              error: 'Bad Request',
              message: `gameType must be one of: ${SUPPORTED_GAMES.join(', ')}.`,
            });
          }
          gameType = body.gameType;
        }
      }

      if (body?.party === true) {
        const rounds = body.rounds ?? PARTY_DEFAULT_ROUNDS;
        if (!Number.isInteger(rounds) || rounds < PARTY_MIN_ROUNDS || rounds > PARTY_MAX_ROUNDS) {
          return reply.status(400).send({
            error: 'Bad Request',
            message: `rounds must be a whole number from ${PARTY_MIN_ROUNDS} to ${PARTY_MAX_ROUNDS}.`,
          });
        }
        if (body.gameType !== undefined) {
          return reply.status(400).send({ error: 'Bad Request', message: 'A party picks its own games.' });
        }
        party = newParty(rounds);
      }

      // Each game sets its own player limits (e.g. Connect Four is exactly 2).
      const gameModule = getGame(gameType)!;
      if (body?.maxPlayers === undefined) maxPlayers = party ? PARTY_MAX_PLAYERS : gameModule.maxPlayers;
      if (!party && (maxPlayers < gameModule.minPlayers || maxPlayers > gameModule.maxPlayers)) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: `${gameType} supports ${gameModule.minPlayers}-${gameModule.maxPlayers} players.`,
        });
      }

      const client = await pool.connect();
      let createdRoomId: string | null = null;

      try {
        for (let attempt = 0; attempt < 10; attempt++) {
          const code = generateRoomCode();
          try {
            await client.query('BEGIN');
            const insertRoomRes = await client.query(
              `INSERT INTO rooms (code, host_user_id, status, max_players, game_type, party)
               VALUES ($1, $2, 'lobby', $3, $4, $5)
               RETURNING id`,
              [code, user.id, maxPlayers, gameType, party ? JSON.stringify(party) : null]
            );

            createdRoomId = insertRoomRes.rows[0].id;

            await client.query(
              `INSERT INTO room_players (room_id, user_id, is_ready)
               VALUES ($1, $2, false)`,
              [createdRoomId, user.id]
            );

            await client.query('COMMIT');
            break;
          } catch (err: any) {
            await client.query('ROLLBACK');
            if (err.code === '23505' && err.constraint === 'rooms_code_key') {
              // Code collision, retry
              continue;
            }
            throw err;
          }
        }
      } finally {
        client.release();
      }

      if (!createdRoomId) {
        return reply.status(500).send({
          error: 'Internal Server Error',
          message: 'Failed to generate a unique room code. Please try again.',
        });
      }

      const room = await getRoomDetailsById(createdRoomId);
      return reply.status(201).send(room);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to create room.',
      });
    }
  });

  // 2. POST /v1/rooms/join - Join a room
  server.post('/v1/rooms/join', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      if (!(await requireOnline(user.id, reply))) return;

      const body = request.body as any;
      if (!body || typeof body !== 'object' || Array.isArray(body)) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Request body must be a JSON object.',
        });
      }

      const { code } = body;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        // Row lock on rooms table
        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status, max_players
           FROM rooms
           WHERE UPPER(code) = $1
           FOR UPDATE`,
          [normalizedCode]
        );

        if (roomRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(404).send({
            error: 'Not Found',
            message: 'Room not found.',
          });
        }

        const room = roomRes.rows[0];

        // Check if user is already a member
        const memberRes = await client.query(
          `SELECT room_id, user_id FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        if (memberRes.rows.length > 0) {
          await client.query('COMMIT');
          const roomDetails = await getRoomDetailsById(room.id);
          return reply.status(200).send(roomDetails);
        }

        // Blocks are enforced here: nobody can join a room that holds someone
        // they blocked or who blocked them (generic message, no detail leaked).
        const blockedRes = await client.query(
          `SELECT 1 FROM room_players rp
           JOIN blocks b ON (b.blocker_id = $2 AND b.blocked_id = rp.user_id)
                         OR (b.blocker_id = rp.user_id AND b.blocked_id = $2)
           WHERE rp.room_id = $1 LIMIT 1`,
          [room.id, user.id]
        );
        if (blockedRes.rows.length > 0) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'You cannot join this room.',
          });
        }

        // A player the host removed cannot come back to the same room.
        const kicked = await client.query('SELECT 1 FROM room_kicks WHERE room_id = $1 AND user_id = $2', [
          room.id,
          user.id,
        ]);
        if (kicked.rows.length > 0) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'You were removed from this room.',
          });
        }

        // Room must be in lobby
        if (room.status !== 'lobby') {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: `Cannot join room with status '${room.status}'. Only lobby rooms can be joined.`,
          });
        }

        // Check player count
        const countRes = await client.query(
          `SELECT COUNT(*)::int AS count FROM room_players WHERE room_id = $1`,
          [room.id]
        );
        const playerCount = countRes.rows[0].count;

        if (playerCount >= room.max_players) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: 'Room is full.',
          });
        }

        // Add player to room
        await client.query(
          `INSERT INTO room_players (room_id, user_id, is_ready)
           VALUES ($1, $2, false)`,
          [room.id, user.id]
        );

        await client.query('COMMIT');

        const roomDetails = await getRoomDetailsById(room.id);
        if (roomDetails) {
          broadcastRoomUpdated(roomDetails.code, roomDetails);
        }
        return reply.status(200).send(roomDetails);
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to join room.',
      });
    }
  });

  // 3. GET /v1/rooms/:code - Room details & players (members only)
  server.get('/v1/rooms/:code', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const roomRes = await pool.query(
        `SELECT id, code, host_user_id, status, max_players, created_at
         FROM rooms
         WHERE UPPER(code) = $1`,
        [normalizedCode]
      );

      if (roomRes.rows.length === 0) {
        return reply.status(404).send({
          error: 'Not Found',
          message: 'Room not found.',
        });
      }

      const room = roomRes.rows[0];

      // Check membership
      const memberRes = await pool.query(
        `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
        [room.id, user.id]
      );

      if (memberRes.rows.length === 0) {
        return reply.status(403).send({
          error: 'Forbidden',
          message: 'Access denied. You are not a member of this room.',
        });
      }

      const roomDetails = await getRoomDetailsById(room.id);
      return reply.status(200).send(roomDetails);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to retrieve room details.',
      });
    }
  });

  // 4. POST /v1/rooms/:code/ready - Mark ready/not ready (members only)
  server.post('/v1/rooms/:code/ready', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const body = request.body as any;
      if (!body || typeof body !== 'object' || Array.isArray(body) || typeof body.ready !== 'boolean') {
        return reply.status(400).send({
          error: 'Bad Request',
          message: "Field 'ready' is required and must be a boolean.",
        });
      }

      const { ready } = body;
      const normalizedCode = code.trim().toUpperCase();

      const roomRes = await pool.query(
        `SELECT id, status FROM rooms WHERE UPPER(code) = $1`,
        [normalizedCode]
      );

      if (roomRes.rows.length === 0) {
        return reply.status(404).send({
          error: 'Not Found',
          message: 'Room not found.',
        });
      }

      const room = roomRes.rows[0];

      // Check membership
      const memberRes = await pool.query(
        `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
        [room.id, user.id]
      );

      if (memberRes.rows.length === 0) {
        return reply.status(403).send({
          error: 'Forbidden',
          message: 'Access denied. You are not a member of this room.',
        });
      }

      if (room.status !== 'lobby') {
        return reply.status(409).send({
          error: 'Conflict',
          message: 'Cannot change ready state after the game has started.',
        });
      }

      await pool.query(
        `UPDATE room_players SET is_ready = $1 WHERE room_id = $2 AND user_id = $3`,
        [ready, room.id, user.id]
      );

      const roomDetails = await getRoomDetailsById(room.id);
      if (roomDetails) {
        broadcastRoomUpdated(roomDetails.code, roomDetails);
      }
      return reply.status(200).send(roomDetails);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to update ready state.',
      });
    }
  });

  // 5. POST /v1/rooms/:code/leave - Leave room
  server.post('/v1/rooms/:code/leave', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status FROM rooms WHERE UPPER(code) = $1 FOR UPDATE`,
          [normalizedCode]
        );

        if (roomRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(404).send({
            error: 'Not Found',
            message: 'Room not found.',
          });
        }

        const room = roomRes.rows[0];

        // Check membership
        const memberRes = await client.query(
          `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        if (memberRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'Access denied. You are not a member of this room.',
          });
        }

        // Delete player from room_players
        await client.query(
          `DELETE FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        // Check remaining players
        const remainingRes = await client.query(
          `SELECT user_id, joined_at FROM room_players WHERE room_id = $1 ORDER BY joined_at ASC`,
          [room.id]
        );

        if (remainingRes.rows.length === 0) {
          // Room became empty, delete room
          await client.query(`DELETE FROM rooms WHERE id = $1`, [room.id]);
          await client.query('COMMIT');
          return reply.status(200).send({
            message: 'Left room successfully. Room was deleted because it became empty.',
            roomDeleted: true,
          });
        }

        // If host left, elect the earliest-joined remaining player as new host
        let newHostAssigned = false;
        if (room.host_user_id === user.id) {
          const newHostId = remainingRes.rows[0].user_id;
          await client.query(
            `UPDATE rooms SET host_user_id = $1 WHERE id = $2`,
            [newHostId, room.id]
          );
          newHostAssigned = true;
        }

        await client.query('COMMIT');

        const updatedRoom = await getRoomDetailsById(room.id);
        if (updatedRoom) {
          broadcastRoomUpdated(updatedRoom.code, updatedRoom);
        }
        return reply.status(200).send({
          message: 'Left room successfully.',
          roomDeleted: false,
          newHostAssigned,
          room: updatedRoom,
        });
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to leave room.',
      });
    }
  });

  // POST /v1/rooms/:code/kick - the host removes a player from the lobby
  server.post('/v1/rooms/:code/kick', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;
      const { code } = request.params as any;
      const target = (request.body as any)?.userId;
      if (typeof code !== 'string' || !code.trim() || !isUuid(target)) {
        return reply.status(400).send({ error: 'Bad Request', message: 'Room code and userId are required.' });
      }
      if (target === user.id) {
        return reply.status(400).send({ error: 'Bad Request', message: 'You cannot remove yourself. Leave the room instead.' });
      }

      const client = await pool.connect();
      let roomId: string;
      let roomCode: string;
      try {
        await client.query('BEGIN');
        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status FROM rooms WHERE UPPER(code) = $1 FOR UPDATE`,
          [code.trim().toUpperCase()]
        );
        const room = roomRes.rows[0];
        if (!room) {
          await client.query('ROLLBACK');
          return reply.status(404).send({ error: 'Not Found', message: 'Room not found.' });
        }
        if (room.host_user_id !== user.id) {
          await client.query('ROLLBACK');
          return reply.status(403).send({ error: 'Forbidden', message: 'Only the host can remove players.' });
        }
        if (room.status !== 'lobby') {
          await client.query('ROLLBACK');
          return reply.status(409).send({ error: 'Conflict', message: 'Players can only be removed before the game starts.' });
        }
        const removed = await client.query(
          'DELETE FROM room_players WHERE room_id = $1 AND user_id = $2 RETURNING user_id',
          [room.id, target]
        );
        if (!removed.rows.length) {
          await client.query('ROLLBACK');
          return reply.status(404).send({ error: 'Not Found', message: 'That player is not in this room.' });
        }
        await client.query('INSERT INTO room_kicks (room_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [room.id, target]);
        await client.query('COMMIT');
        roomId = room.id;
        roomCode = room.code;
      } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        throw err;
      } finally {
        client.release();
      }

      emitToUser(target, 'room:kicked', { code: roomCode });
      leaveRoomChannel(target, roomCode);
      const details = await getRoomDetailsById(roomId);
      if (details) broadcastRoomUpdated(details.code, details);
      return reply.status(200).send(details);
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({ error: 'Internal Server Error', message: 'Failed to remove player.' });
    }
  });

  // 6. POST /v1/rooms/:code/start - Start game (host only)
  server.post('/v1/rooms/:code/start', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;

      const { code } = request.params as any;
      if (typeof code !== 'string' || !code.trim()) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Room code is required.',
        });
      }

      const normalizedCode = code.trim().toUpperCase();

      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        const roomRes = await client.query(
          `SELECT id, code, host_user_id, status, game_type, party FROM rooms WHERE UPPER(code) = $1 FOR UPDATE`,
          [normalizedCode]
        );

        if (roomRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(404).send({
            error: 'Not Found',
            message: 'Room not found.',
          });
        }

        const room = roomRes.rows[0];

        // Check membership
        const memberRes = await client.query(
          `SELECT 1 FROM room_players WHERE room_id = $1 AND user_id = $2`,
          [room.id, user.id]
        );

        if (memberRes.rows.length === 0) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'Access denied. You are not a member of this room.',
          });
        }

        // Host only check
        if (room.host_user_id !== user.id) {
          await client.query('ROLLBACK');
          return reply.status(403).send({
            error: 'Forbidden',
            message: 'Only the host can start the game.',
          });
        }

        // Room status must be lobby
        if (room.status !== 'lobby') {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: `Cannot start room with status '${room.status}'.`,
          });
        }

        // Check players
        const playersRes = await client.query(
          `SELECT user_id, is_ready FROM room_players WHERE room_id = $1 ORDER BY joined_at ASC`,
          [room.id]
        );

        if (playersRes.rows.length < 2) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: 'At least 2 players are required to start the game.',
          });
        }

        const notReady = playersRes.rows.some((p: any) => !p.is_ready);
        if (notReady) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: 'All players must be ready to start the game.',
          });
        }

        // Party Mode: the first round's game is drawn now, from those that fit this group.
        let startParty: PartyState | null = null;
        if (room.party) {
          const first = pickGame(playersRes.rows.length, null);
          if (!first) {
            await client.query('ROLLBACK');
            return reply.status(409).send({ error: 'Conflict', message: 'No game fits this many players.' });
          }
          room.game_type = first;
          startParty = { ...(room.party as PartyState), round: 1 };
        }

        const gameModule = getGame(room.game_type);
        if (!gameModule) {
          await client.query('ROLLBACK');
          return reply.status(409).send({ error: 'Conflict', message: 'This room has an unknown game.' });
        }
        if (playersRes.rows.length < gameModule.minPlayers || playersRes.rows.length > gameModule.maxPlayers) {
          await client.query('ROLLBACK');
          return reply.status(409).send({
            error: 'Conflict',
            message: `This game needs ${gameModule.minPlayers}-${gameModule.maxPlayers} players.`,
          });
        }

        // Update status to 'playing'
        await client.query(
          `UPDATE rooms SET status = 'playing', game_state = $2, game_type = $3, party = $4 WHERE id = $1`,
          [
            room.id,
            JSON.stringify(gameModule.init(playersRes.rows.map((p: any) => p.user_id), Date.now())),
            room.game_type,
            startParty ? JSON.stringify(startParty) : room.party ? JSON.stringify(room.party) : null,
          ]
        );

        // Remember who played together (feeds recent players / friend requests).
        await client.query(
          `INSERT INTO recent_players (user_id, other_id, last_played_at)
           SELECT a.user_id, b.user_id, NOW()
           FROM room_players a JOIN room_players b ON a.room_id = b.room_id AND a.user_id <> b.user_id
           WHERE a.room_id = $1
           ON CONFLICT (user_id, other_id) DO UPDATE SET last_played_at = NOW()`,
          [room.id]
        );

        await client.query('COMMIT');

        logEvent('game_started', user.id, {
          gameType: room.game_type,
          players: playersRes.rows.length,
          source: 'room',
        });

        const updatedRoom = await getRoomDetailsById(room.id);
        if (updatedRoom) {
          broadcastRoomStarted(updatedRoom.code, updatedRoom);
        }
        return reply.status(200).send(updatedRoom);
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({
        error: 'Internal Server Error',
        message: 'Failed to start game.',
      });
    }
  });
}
