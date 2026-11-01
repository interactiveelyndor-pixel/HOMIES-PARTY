import { FastifyRequest, FastifyReply } from 'fastify';
import { firebaseAuth } from './firebase';
import { pool } from './db';

export interface FirebaseUserData {
  uid: string;
  email?: string;
}

declare module 'fastify' {
  interface FastifyRequest {
    firebaseUser?: FirebaseUserData;
  }
}

export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Missing or invalid Authorization header. Format must be Bearer <token>.',
    });
    return;
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Authentication token is missing.',
    });
    return;
  }

  try {
    const decoded = await firebaseAuth.verifyIdToken(token);
    request.firebaseUser = {
      uid: decoded.uid,
      email: decoded.email,
    };
  } catch (err: any) {
    await reply.status(401).send({
      error: 'Unauthorized',
      message: 'Invalid or expired authentication token.',
    });
    return;
  }

  // Suspended accounts are refused on every authenticated route.
  const banned = await pool.query('SELECT 1 FROM users WHERE firebase_uid = $1 AND banned_at IS NOT NULL', [
    request.firebaseUser.uid,
  ]);
  if (banned.rows.length > 0) {
    await reply.status(403).send({ error: 'Forbidden', message: 'This account has been suspended.' });
  }
}
