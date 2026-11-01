import dotenv from 'dotenv';
dotenv.config();

import { initializeApp, getApps, applicationDefault } from 'firebase-admin/app';
import type { Auth } from 'firebase-admin/auth';
import { getAuth } from 'firebase-admin/auth';
import path from 'path';
import fs from 'fs';

// Local testing only: the bearer token IS the uid ("dev-alice"). Never allowed in production.
export const DEV_AUTH = process.env.DEV_AUTH === 'true';
if (DEV_AUTH && process.env.NODE_ENV === 'production') {
  throw new Error('DEV_AUTH must not be enabled when NODE_ENV=production.');
}

if (!DEV_AUTH && getApps().length === 0) {
  const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (credPath && !path.isAbsolute(credPath)) {
    const candidateFromCwd = path.resolve(process.cwd(), credPath);
    const candidateFromServerRoot = path.resolve(__dirname, '..', credPath);
    if (fs.existsSync(candidateFromCwd)) {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = candidateFromCwd;
    } else if (fs.existsSync(candidateFromServerRoot)) {
      process.env.GOOGLE_APPLICATION_CREDENTIALS = candidateFromServerRoot;
    }
  }

  initializeApp({
    credential: applicationDefault(),
  });
}

if (DEV_AUTH) console.warn('WARNING: DEV_AUTH is on - any "dev-<name>" token is accepted. Local testing only.');

export const firebaseAuth: Pick<Auth, 'verifyIdToken' | 'deleteUser'> = DEV_AUTH
  ? ({
      verifyIdToken: async (t: string) => {
        if (!/^dev-[A-Za-z0-9_-]{1,20}$/.test(t)) throw new Error('Invalid dev token');
        return { uid: t };
      },
      deleteUser: async () => {},
    } as unknown as Pick<Auth, 'verifyIdToken' | 'deleteUser'>)
  : getAuth();
