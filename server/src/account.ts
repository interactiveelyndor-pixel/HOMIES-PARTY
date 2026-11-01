import { FastifyInstance } from 'fastify';
import { pool } from './db';
import { authenticate } from './auth';
import { firebaseAuth } from './firebase';
import { getDbUser, getRoomDetailsById } from './rooms';
import { broadcastRoomUpdated } from './socket';

export async function accountRoutes(server: FastifyInstance): Promise<void> {
  // POST /v1/me/delete { confirm: true } - permanently deletes the caller's account.
  // Friendships, requests, blocks, recent players and room seats are removed;
  // reports are kept (reporter becomes anonymous); rooms they hosted pass to
  // the next player or disappear if empty.
  server.post('/v1/me/delete', { preHandler: authenticate }, async (request, reply) => {
    try {
      const user = await getDbUser(request, reply);
      if (!user) return;
      if ((request.body as any)?.confirm !== true) {
        return reply.status(400).send({ error: 'Bad Request', message: 'Send { "confirm": true } to delete your account.' });
      }

      const client = await pool.connect();
      const touched: string[] = [];
      try {
        await client.query('BEGIN');
        const rooms = await client.query(
          `SELECT r.id, r.host_user_id FROM rooms r
           JOIN room_players rp ON rp.room_id = r.id AND rp.user_id = $1
           ORDER BY r.id FOR UPDATE OF r`,
          [user.id]
        );
        for (const room of rooms.rows) {
          await client.query('DELETE FROM room_players WHERE room_id = $1 AND user_id = $2', [room.id, user.id]);
          const next = await client.query(
            'SELECT user_id FROM room_players WHERE room_id = $1 ORDER BY joined_at ASC LIMIT 1',
            [room.id]
          );
          if (!next.rows.length) {
            await client.query('DELETE FROM rooms WHERE id = $1', [room.id]);
          } else {
            if (room.host_user_id === user.id) {
              await client.query('UPDATE rooms SET host_user_id = $1 WHERE id = $2', [next.rows[0].user_id, room.id]);
            }
            touched.push(room.id);
          }
        }
        // Rooms where they are host but somehow have no seat must not cascade-delete others.
        await client.query(
          `UPDATE rooms r SET host_user_id = (
             SELECT user_id FROM room_players WHERE room_id = r.id ORDER BY joined_at ASC LIMIT 1)
           WHERE r.host_user_id = $1 AND EXISTS (SELECT 1 FROM room_players WHERE room_id = r.id)`,
          [user.id]
        );
        await client.query('DELETE FROM users WHERE id = $1', [user.id]);
        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        throw err;
      } finally {
        client.release();
      }

      for (const id of touched) {
        const room = await getRoomDetailsById(id);
        if (room) broadcastRoomUpdated(room.code, room);
      }

      // Best effort: the backend data is already gone; a leftover Firebase
      // guest record holds no profile and is retried on the next cleanup.
      try {
        await firebaseAuth.deleteUser(user.firebase_uid);
      } catch (err) {
        server.log.warn({ err }, 'Firebase user deletion failed after DB deletion');
      }
      return reply.status(200).send({ message: 'Account deleted.' });
    } catch (error: any) {
      server.log.error(error);
      return reply.status(500).send({ error: 'Internal Server Error', message: 'Failed to delete account.' });
    }
  });
}
