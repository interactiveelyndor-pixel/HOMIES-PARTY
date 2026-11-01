import dotenv from 'dotenv';
dotenv.config();

import { io as Client, Socket } from 'socket.io-client';

async function getGuestToken(apiKey: string): Promise<string> {
  const signupRes = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    }
  );

  if (!signupRes.ok) {
    const errBody = await signupRes.text();
    throw new Error(`Firebase anonymous sign-up failed with status ${signupRes.status}: ${errBody}`);
  }

  const signupData = (await signupRes.json()) as { idToken?: string };
  if (!signupData.idToken) {
    throw new Error('Firebase anonymous sign-up did not return an idToken.');
  }

  return signupData.idToken;
}

async function registerGuest(baseUrl: string, token: string): Promise<any> {
  const res = await fetch(`${baseUrl}/v1/auth/guest`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({}),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to create guest user (status ${res.status}): ${text}`);
  }

  return await res.json();
}

function connectSocket(baseUrl: string, token?: string): Promise<{ socket: Socket; connected: boolean; error?: any }> {
  return new Promise((resolve) => {
    const socket = Client(baseUrl, {
      auth: token ? { token } : {},
      reconnection: false,
      timeout: 4000,
      transports: ['polling', 'websocket'],
    });

    const timer = setTimeout(() => {
      socket.disconnect();
      resolve({ socket, connected: false, error: new Error('Socket connection timed out') });
    }, 5000);

    socket.on('connect', () => {
      clearTimeout(timer);
      resolve({ socket, connected: true });
    });

    socket.on('connect_error', (err) => {
      clearTimeout(timer);
      resolve({ socket, connected: false, error: err });
    });
  });
}

async function run() {
  const apiKey = process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    console.error('FAIL: FIREBASE_WEB_API_KEY environment variable is not defined.');
    process.exit(1);
  }

  const port = process.env.PORT || '3000';
  const baseUrl = process.env.BASE_URL || `http://127.0.0.1:${port}`;

  let allPassed = true;

  // Initialize guest tokens and users
  let tokenA = '';
  let tokenB = '';
  let tokenC = '';
  let userA: any = null;
  let userB: any = null;
  let userC: any = null;

  try {
    tokenA = await getGuestToken(apiKey);
    tokenB = await getGuestToken(apiKey);
    tokenC = await getGuestToken(apiKey);

    userA = await registerGuest(baseUrl, tokenA);
    userB = await registerGuest(baseUrl, tokenB);
    userC = await registerGuest(baseUrl, tokenC);
  } catch (err: any) {
    console.error(`FAIL: Failed to initialize guest users: ${err.message}`);
    process.exit(1);
  }

  const activeSockets: Socket[] = [];

  try {
    // 1. Authenticated user can connect
    const authConn = await connectSocket(baseUrl, tokenA);
    if (authConn.connected) {
      console.log('PASS: Authenticated user can connect to Socket.IO');
      activeSockets.push(authConn.socket);
    } else {
      console.error('FAIL: Authenticated user failed to connect:', authConn.error?.message);
      allPassed = false;
    }

    // 2. Connection without a token is rejected
    const noTokenConn = await connectSocket(baseUrl);
    if (!noTokenConn.connected && noTokenConn.error) {
      console.log('PASS: Connection without a token was rejected');
    } else {
      console.error('FAIL: Connection without token was not rejected');
      allPassed = false;
    }
    noTokenConn.socket.disconnect();

    // 3. Invalid token is rejected
    const invalidTokenConn = await connectSocket(baseUrl, 'invalid_fake_token_12345');
    if (!invalidTokenConn.connected && invalidTokenConn.error) {
      console.log('PASS: Connection with invalid token was rejected');
    } else {
      console.error('FAIL: Connection with invalid token was not rejected');
      allPassed = false;
    }
    invalidTokenConn.socket.disconnect();

    // Connection with token but no row in users table is rejected
    const unregisteredToken = await getGuestToken(apiKey);
    const unregConn = await connectSocket(baseUrl, unregisteredToken);
    if (!unregConn.connected && unregConn.error) {
      console.log('PASS: Connection for user without DB profile was rejected');
    } else {
      console.error('FAIL: Connection for user without DB profile was not rejected');
      allPassed = false;
    }
    unregConn.socket.disconnect();

    // 4. Create a room via REST
    const createRes = await fetch(`${baseUrl}/v1/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ maxPlayers: 4 }),
    });

    if (!createRes.ok) {
      const errText = await createRes.text();
      console.error(`FAIL: Failed to create room for realtime test: ${errText}`);
      process.exit(1);
    }

    const createdRoom = (await createRes.json()) as any;
    const roomCode = createdRoom.code;

    // 4b. Member can subscribe and receives current room state in acknowledgement
    const socketA = authConn.socket;
    const subAck = await new Promise<any>((resolve) => {
      socketA.emit('room:subscribe', { code: roomCode }, (res: any) => {
        resolve(res);
      });
    });

    const receivedCode = subAck?.room?.code || subAck?.code;
    const receivedPlayers = subAck?.room?.players || subAck?.players;

    if (receivedCode === roomCode && Array.isArray(receivedPlayers) && receivedPlayers.length === 1) {
      console.log('PASS: Room member subscribed and received current room state');
    } else {
      console.error('FAIL: Member subscribe acknowledgement failed or invalid payload:', subAck);
      allPassed = false;
    }

    // 5. Non-member cannot subscribe
    const nonMemberConn = await connectSocket(baseUrl, tokenC);
    if (!nonMemberConn.connected) {
      console.error('FAIL: User C could not connect:', nonMemberConn.error);
      allPassed = false;
    } else {
      activeSockets.push(nonMemberConn.socket);
      const nonMemberAck = await new Promise<any>((resolve) => {
        nonMemberConn.socket.emit('room:subscribe', { code: roomCode }, (res: any) => {
          resolve(res);
        });
      });

      if (nonMemberAck?.error === 'Forbidden') {
        console.log('PASS: Non-member subscription was rejected (403 Forbidden)');
      } else {
        console.error('FAIL: Non-member subscription was not rejected properly:', nonMemberAck);
        allPassed = false;
      }
    }

    // 6. When user B joins through REST route, subscribed user A receives "room:updated"
    const joinUpdatePromise = new Promise<any>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timed out waiting for room:updated on join')), 6000);
      socketA.once('room:updated', (data: any) => {
        clearTimeout(timeout);
        resolve(data);
      });
    });

    const joinRes = await fetch(`${baseUrl}/v1/rooms/join`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({ code: roomCode }),
    });

    if (!joinRes.ok) {
      console.error(`FAIL: User B failed to join room: ${await joinRes.text()}`);
      allPassed = false;
    } else {
      const updatedPayload = await joinUpdatePromise;
      const players = updatedPayload?.players;
      if (Array.isArray(players) && players.length === 2 && players.some((p: any) => p.userId === userB.id)) {
        console.log('PASS: Subscribed User A received "room:updated" when User B joined via REST');
      } else {
        console.error('FAIL: "room:updated" payload after join was invalid:', updatedPayload);
        allPassed = false;
      }
    }

    // 7. When B marks ready, A receives "room:updated"
    const readyUpdatePromise = new Promise<any>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timed out waiting for room:updated on ready')), 6000);
      socketA.once('room:updated', (data: any) => {
        clearTimeout(timeout);
        resolve(data);
      });
    });

    const readyRes = await fetch(`${baseUrl}/v1/rooms/${roomCode}/ready`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({ ready: true }),
    });

    if (!readyRes.ok) {
      console.error(`FAIL: User B failed to mark ready: ${await readyRes.text()}`);
      allPassed = false;
    } else {
      const updatedPayload = await readyUpdatePromise;
      const playerB = updatedPayload?.players?.find((p: any) => p.userId === userB.id);
      if (playerB?.isReady === true) {
        console.log('PASS: Subscribed User A received "room:updated" when User B marked ready');
      } else {
        console.error('FAIL: "room:updated" payload after ready was invalid:', updatedPayload);
        allPassed = false;
      }
    }

    // 8. When the host starts, subscribed members receive "room:started"
    // User B also connects socket and subscribes
    const userBConn = await connectSocket(baseUrl, tokenB);
    if (!userBConn.connected) {
      console.error('FAIL: User B socket connection failed:', userBConn.error);
      allPassed = false;
    } else {
      activeSockets.push(userBConn.socket);
      await new Promise<any>((resolve) => {
        userBConn.socket.emit('room:subscribe', { code: roomCode }, (res: any) => {
          resolve(res);
        });
      });
    }

    // Host (User A) marks ready too
    await fetch(`${baseUrl}/v1/rooms/${roomCode}/ready`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ ready: true }),
    });

    const startPromiseA = new Promise<any>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timed out waiting for room:started on User A')), 6000);
      socketA.once('room:started', (data: any) => {
        clearTimeout(timeout);
        resolve(data);
      });
    });

    const startPromiseB = new Promise<any>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timed out waiting for room:started on User B')), 6000);
      userBConn.socket.once('room:started', (data: any) => {
        clearTimeout(timeout);
        resolve(data);
      });
    });

    const startRes = await fetch(`${baseUrl}/v1/rooms/${roomCode}/start`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });

    if (!startRes.ok) {
      console.error(`FAIL: Host start game failed: ${await startRes.text()}`);
      allPassed = false;
    } else {
      const [payloadA, payloadB] = await Promise.all([startPromiseA, startPromiseB]);
      if (payloadA?.status === 'playing' && payloadB?.status === 'playing') {
        console.log('PASS: Subscribed members (User A and User B) received "room:started" event');
      } else {
        console.error('FAIL: "room:started" payloads invalid:', { payloadA, payloadB });
        allPassed = false;
      }
    }
  } catch (err: any) {
    console.error(`FAIL: Exception during realtime tests: ${err.message}`);
    allPassed = false;
  } finally {
    for (const socket of activeSockets) {
      socket.disconnect();
    }
  }

  if (!allPassed) {
    process.exit(1);
  }
}

run();
