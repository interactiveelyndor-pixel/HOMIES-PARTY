import dotenv from 'dotenv';
dotenv.config();

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

async function run() {
  const apiKey = process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    console.error('FAIL: FIREBASE_WEB_API_KEY environment variable is not defined.');
    process.exit(1);
  }

  const port = process.env.PORT || '3000';
  const baseUrl = process.env.BASE_URL || `http://127.0.0.1:${port}`;

  let allPassed = true;

  // 1. Obtain tokens and register guest users
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

    if (userA?.id && userB?.id && userC?.id) {
      console.log('PASS: Registered guest users (User A, User B, User C)');
    } else {
      console.error('FAIL: Guest users registration response invalid:', { userA, userB, userC });
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Failed to initialize guest users: ${err.message}`);
    process.exit(1);
  }

  // 2. User A creates a room (POST /v1/rooms)
  let roomCode = '';
  try {
    const res = await fetch(`${baseUrl}/v1/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ maxPlayers: 4 }),
    });

    if (res.status === 201 || res.status === 200) {
      const room = (await res.json()) as any;
      if (
        room?.code &&
        room.code.length === 6 &&
        room.status === 'lobby' &&
        Array.isArray(room.players) &&
        room.players.length === 1 &&
        room.players[0].isHost === true
      ) {
        roomCode = room.code;
        console.log(`PASS: User A created room with code '${roomCode}' (status: lobby, creator is host)`);
      } else {
        console.error('FAIL: POST /v1/rooms returned invalid room payload:', room);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: POST /v1/rooms returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: POST /v1/rooms failed with error: ${err.message}`);
    allPassed = false;
  }

  if (!roomCode) {
    console.error('FAIL: Cannot proceed with room tests without a valid room code.');
    process.exit(1);
  }

  // 3. User B joins the room using case-insensitive code (POST /v1/rooms/join)
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/join`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({ code: roomCode.toLowerCase() }),
    });

    if (res.status === 200) {
      const room = (await res.json()) as any;
      if (
        room?.players?.length === 2 &&
        room.players.some((p: any) => p.userId === userB.id || p.id === userB.id)
      ) {
        console.log('PASS: User B joined the room with case-insensitive code (2 players now in room)');
      } else {
        console.error('FAIL: POST /v1/rooms/join did not include User B:', room);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: POST /v1/rooms/join returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: POST /v1/rooms/join failed with error: ${err.message}`);
    allPassed = false;
  }

  // 4. User A (host) marks ready (POST /v1/rooms/:code/ready)
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/${roomCode}/ready`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ ready: true }),
    });

    if (res.status === 200) {
      const room = (await res.json()) as any;
      const hostPlayer = room?.players?.find((p: any) => p.userId === userA.id || p.id === userA.id);
      if (hostPlayer?.isReady === true) {
        console.log('PASS: User A marked ready');
      } else {
        console.error('FAIL: User A ready status not updated:', room);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: User A ready request returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: User A ready request failed with error: ${err.message}`);
    allPassed = false;
  }

  // 5. User B marks ready (POST /v1/rooms/:code/ready)
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/${roomCode}/ready`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({ ready: true }),
    });

    if (res.status === 200) {
      const room = (await res.json()) as any;
      const playerB = room?.players?.find((p: any) => p.userId === userB.id || p.id === userB.id);
      if (playerB?.isReady === true) {
        console.log('PASS: User B marked ready (both players ready)');
      } else {
        console.error('FAIL: User B ready status not updated:', room);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: User B ready request returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: User B ready request failed with error: ${err.message}`);
    allPassed = false;
  }

  // 6. Host (User A) starts the game (POST /v1/rooms/:code/start)
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/${roomCode}/start`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });

    if (res.status === 200) {
      const room = (await res.json()) as any;
      if (room?.status === 'playing') {
        console.log('PASS: Host started the game successfully (status is playing)');
      } else {
        console.error("FAIL: Started room status is not 'playing':", room);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: POST /v1/rooms/:code/start returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: POST /v1/rooms/:code/start failed with error: ${err.message}`);
    allPassed = false;
  }

  // 7. Third guest (User C) tries to join the started room (POST /v1/rooms/join) -> Expect 409
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/join`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenC}`,
      },
      body: JSON.stringify({ code: roomCode }),
    });

    if (res.status === 409) {
      console.log('PASS: Third guest trying to join started room received 409 Conflict');
    } else {
      const err = await res.text();
      console.error(`FAIL: Joining started room returned unexpected status ${res.status} (expected 409): ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Third guest join attempt failed with error: ${err.message}`);
    allPassed = false;
  }

  // 8. Non-member (User C) tries to read room details (GET /v1/rooms/:code) -> Expect 403
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/${roomCode}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${tokenC}`,
      },
    });

    if (res.status === 403) {
      console.log('PASS: Non-member reading the room received 403 Forbidden');
    } else {
      const err = await res.text();
      console.error(`FAIL: Non-member reading room returned status ${res.status} (expected 403): ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Non-member reading room failed with error: ${err.message}`);
    allPassed = false;
  }

  // 9. Member (User A) reading room details (GET /v1/rooms/:code) -> Expect 200
  try {
    const res = await fetch(`${baseUrl}/v1/rooms/${roomCode}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });

    if (res.status === 200) {
      const room = (await res.json()) as any;
      if (
        room?.code === roomCode &&
        Array.isArray(room.players) &&
        room.players.every((p: any) => p.nickname && typeof p.isReady === 'boolean' && typeof p.isHost === 'boolean')
      ) {
        console.log('PASS: Member reading the room returned room details and player list successfully');
      } else {
        console.error('FAIL: Member reading room payload missing required player details:', room);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: Member reading room returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Member reading room request failed with error: ${err.message}`);
    allPassed = false;
  }

  // 10. Requirement 7: Unregistered Firebase user (no row in users) returns 404
  try {
    const unregToken = await getGuestToken(apiKey);
    const res = await fetch(`${baseUrl}/v1/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${unregToken}`,
      },
      body: JSON.stringify({}),
    });

    if (res.status === 404) {
      const err = await res.json() as any;
      if (err.message) {
        console.log('PASS: Logged-in Firebase user without row in users received 404');
      } else {
        console.error('FAIL: 404 response missing clear message:', err);
        allPassed = false;
      }
    } else {
      console.error(`FAIL: Unregistered user received status ${res.status} (expected 404)`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Unregistered user test failed with error: ${err.message}`);
    allPassed = false;
  }

  // 11. Requirement 8: Input validation (400 on invalid input)
  try {
    const invalidMaxPlayersRes = await fetch(`${baseUrl}/v1/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ maxPlayers: 5 }),
    });

    if (invalidMaxPlayersRes.status === 400) {
      console.log('PASS: Invalid maxPlayers (5) rejected with 400 Bad Request');
    } else {
      console.error(`FAIL: Invalid maxPlayers returned status ${invalidMaxPlayersRes.status}`);
      allPassed = false;
    }

    const invalidJoinRes = await fetch(`${baseUrl}/v1/rooms/join`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ code: '' }),
    });

    if (invalidJoinRes.status === 400) {
      console.log('PASS: Empty room code on join rejected with 400 Bad Request');
    } else {
      console.error(`FAIL: Empty room code on join returned status ${invalidJoinRes.status}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Input validation test failed with error: ${err.message}`);
    allPassed = false;
  }

  // 12. Requirement 5: Room leave, host migration, and room deletion when empty
  try {
    // Create new room for leave test
    const newRoomRes = await fetch(`${baseUrl}/v1/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ maxPlayers: 2 }),
    });
    const newRoom = (await newRoomRes.json()) as any;
    const leaveRoomCode = newRoom.code;

    // User B joins
    await fetch(`${baseUrl}/v1/rooms/join`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({ code: leaveRoomCode }),
    });

    // Host (User A) leaves -> User B should become new host
    const hostLeaveRes = await fetch(`${baseUrl}/v1/rooms/${leaveRoomCode}/leave`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${tokenA}`,
      },
    });

    if (hostLeaveRes.status === 200) {
      const data = (await hostLeaveRes.json()) as any;
      if (data.room?.hostUserId === userB.id || data.room?.host_user_id === userB.id) {
        console.log('PASS: Host left room; earliest remaining player (User B) became new host');
      } else {
        console.error('FAIL: Host transfer did not assign User B:', data);
        allPassed = false;
      }
    } else {
      console.error(`FAIL: Host leave returned status ${hostLeaveRes.status}`);
      allPassed = false;
    }

    // Last member (User B) leaves -> room deleted
    const lastLeaveRes = await fetch(`${baseUrl}/v1/rooms/${leaveRoomCode}/leave`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${tokenB}`,
      },
    });

    if (lastLeaveRes.status === 200) {
      const data = (await lastLeaveRes.json()) as any;
      if (data.roomDeleted === true) {
        console.log('PASS: Last player left room; room was deleted because it became empty');
      } else {
        console.error('FAIL: Room was not deleted when last player left:', data);
        allPassed = false;
      }
    } else {
      console.error(`FAIL: Last player leave returned status ${lastLeaveRes.status}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: Room leave test failed with error: ${err.message}`);
    allPassed = false;
  }

  if (!allPassed) {
    process.exit(1);
  }
}

run();
