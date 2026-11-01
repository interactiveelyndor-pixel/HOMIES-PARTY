import dotenv from 'dotenv';
dotenv.config();

import Fastify from 'fastify';
import { pool } from './db';
import { authenticate } from './auth';
import { roomRoutes } from './rooms';
import { socialRoutes } from './social';
import { accountRoutes } from './account';
import { adminRoutes } from './admin';
import { startEventRetention } from './events';
import { eligibilityRoutes } from './eligibility';
import { progressRoutes } from './progress';
import { startSweeper } from './sweeper';
import { setupSocketIO } from './socket';

const server = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    redact: ['req.headers.authorization'],
  },
});

// Browser testing (Flutter web on another port) needs CORS. Dev only.
if (process.env.DEV_AUTH === 'true') {
  server.addHook('onRequest', async (request, reply) => {
    reply.header('Access-Control-Allow-Origin', '*');
    reply.header('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    reply.header('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
    if (request.method === 'OPTIONS') return reply.status(204).send();
  });
}

server.addContentTypeParser('application/json', { parseAs: 'string' }, (_req, body, done) => {
  if (!body || (typeof body === 'string' && body.trim() === '')) {
    done(null, {});
    return;
  }
  try {
    const json = JSON.parse(body as string);
    done(null, json);
  } catch (err: any) {
    err.statusCode = 400;
    done(err, undefined);
  }
});

server.get('/health', async () => {
  return {
    status: 'ok',
    app: 'Homies Party Backend',
  };
});

server.get('/health/db', async (_request, reply) => {
  try {
    await pool.query('SELECT 1');
    return { db: 'ok' };
  } catch (error: any) {
    server.log.error(error);
    reply.status(500);
    const detail =
      error?.message ||
      (error?.aggregateErrors && error.aggregateErrors[0]?.message) ||
      error?.code ||
      'Database connection failed';
    return {
      db: 'error',
      message: detail,
    };
  }
});

// POST /v1/auth/guest (needs login)
server.post('/v1/auth/guest', { preHandler: authenticate }, async (request, reply) => {
  try {
    const uid = request.firebaseUser!.uid;

    const findRes = await pool.query(
      'SELECT id, firebase_uid, nickname, avatar, created_at FROM users WHERE firebase_uid = $1',
      [uid]
    );

    if (findRes.rows.length > 0) {
      return reply.send(findRes.rows[0]);
    }

    const randomDigits = Math.floor(1000 + Math.random() * 9000).toString();
    const nickname = `Guest${randomDigits}`;

    const insertRes = await pool.query(
      `INSERT INTO users (firebase_uid, nickname)
       VALUES ($1, $2)
       ON CONFLICT (firebase_uid) DO UPDATE SET firebase_uid = EXCLUDED.firebase_uid
       RETURNING id, firebase_uid, nickname, avatar, created_at`,
      [uid, nickname]
    );

    return reply.status(201).send(insertRes.rows[0]);
  } catch (error: any) {
    server.log.error(error);
    return reply.status(500).send({
      error: 'Internal Server Error',
      message: 'Failed to authenticate guest user.',
    });
  }
});

// GET /v1/me (needs login)
server.get('/v1/me', { preHandler: authenticate }, async (request, reply) => {
  try {
    const uid = request.firebaseUser!.uid;

    const userRes = await pool.query(
      'SELECT id, firebase_uid, nickname, avatar, created_at FROM users WHERE firebase_uid = $1',
      [uid]
    );

    if (userRes.rows.length === 0) {
      return reply.status(404).send({
        error: 'Not Found',
        message: 'User profile not found.',
      });
    }

    return reply.send(userRes.rows[0]);
  } catch (error: any) {
    server.log.error(error);
    return reply.status(500).send({
      error: 'Internal Server Error',
      message: 'Failed to retrieve profile.',
    });
  }
});

// PATCH /v1/me (needs login)
server.patch('/v1/me', { preHandler: authenticate }, async (request, reply) => {
  try {
    const body = request.body as Record<string, any> | undefined;

    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return reply.status(400).send({
        error: 'Bad Request',
        message: 'Request body must be a JSON object.',
      });
    }

    const { nickname, avatar } = body;

    if (nickname === undefined && avatar === undefined) {
      return reply.status(400).send({
        error: 'Bad Request',
        message: 'At least nickname or avatar must be provided.',
      });
    }

    if (nickname !== undefined) {
      if (typeof nickname !== 'string' || nickname.trim().length < 2 || nickname.trim().length > 20) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Nickname must be a string between 2 and 20 characters.',
        });
      }
    }

    if (avatar !== undefined) {
      if (typeof avatar !== 'string' || avatar.length > 30) {
        return reply.status(400).send({
          error: 'Bad Request',
          message: 'Avatar must be a string up to 30 characters.',
        });
      }
    }

    const uid = request.firebaseUser!.uid;
    const updates: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (nickname !== undefined) {
      updates.push(`nickname = $${idx++}`);
      values.push(nickname.trim());
    }

    if (avatar !== undefined) {
      updates.push(`avatar = $${idx++}`);
      values.push(avatar);
    }

    values.push(uid);

    const query = `
      UPDATE users
      SET ${updates.join(', ')}
      WHERE firebase_uid = $${idx}
      RETURNING id, firebase_uid, nickname, avatar, created_at
    `;

    const updateRes = await pool.query(query, values);

    if (updateRes.rows.length === 0) {
      return reply.status(404).send({
        error: 'Not Found',
        message: 'User profile not found.',
      });
    }

    return reply.send(updateRes.rows[0]);
  } catch (error: any) {
    server.log.error(error);
    return reply.status(500).send({
      error: 'Internal Server Error',
      message: 'Failed to update profile.',
    });
  }
});

server.register(roomRoutes);
server.register(socialRoutes);
server.register(accountRoutes);
server.register(eligibilityRoutes);
server.register(progressRoutes);
if ((process.env.ADMIN_TOKEN ?? '').length >= 16) {
  server.register(adminRoutes, { token: process.env.ADMIN_TOKEN as string });
}

export const io = setupSocketIO(server.server);

const port = Number(process.env.PORT) || 3000;
const host = process.env.HOST || '0.0.0.0';

export const start = async () => {
  try {
    await server.listen({ port, host });
    startEventRetention();
    if (process.env.DISABLE_SWEEPER !== 'true') startSweeper();
    console.log(`Server listening on http://${host}:${port}`);
  } catch (err) {
    server.log.error(err);
    process.exit(1);
  }
};

start();
