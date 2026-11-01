import dotenv from 'dotenv';
dotenv.config();

async function run() {
  const apiKey = process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    console.error('FAIL: FIREBASE_WEB_API_KEY environment variable is not defined.');
    process.exit(1);
  }

  const port = process.env.PORT || '3000';
  const baseUrl = process.env.BASE_URL || `http://127.0.0.1:${port}`;

  let allPassed = true;

  // 1. Obtain anonymous guest token from Firebase Auth REST API
  let token = '';
  try {
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
      console.error(`FAIL: Firebase anonymous sign-up failed with status ${signupRes.status}: ${errBody}`);
      process.exit(1);
    }

    const signupData = (await signupRes.json()) as { idToken?: string };
    if (!signupData.idToken) {
      console.error('FAIL: Firebase anonymous sign-up did not return an idToken.');
      process.exit(1);
    }

    token = signupData.idToken;
  } catch (err: any) {
    const detail = err?.cause?.message || err?.cause?.code || err?.message || String(err);
    console.error(`FAIL: Exception during Firebase anonymous sign-up: ${detail}`);
    process.exit(1);
  }

  // 2. Call POST /v1/auth/guest (Create or get guest user)
  try {
    const res = await fetch(`${baseUrl}/v1/auth/guest`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({}),
    });

    if (res.status === 200 || res.status === 201) {
      const data = (await res.json()) as any;
      if (data && data.id && typeof data.nickname === 'string' && data.nickname.startsWith('Guest')) {
        console.log('PASS: POST /v1/auth/guest created/retrieved guest user');
      } else {
        console.error('FAIL: POST /v1/auth/guest response data format invalid:', data);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: POST /v1/auth/guest returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: POST /v1/auth/guest request failed: ${err.message}`);
    allPassed = false;
  }

  // 3. Call GET /v1/me (Read profile)
  try {
    const res = await fetch(`${baseUrl}/v1/me`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (res.status === 200) {
      const data = (await res.json()) as any;
      if (data && data.id && data.nickname) {
        console.log('PASS: GET /v1/me returned profile successfully');
      } else {
        console.error('FAIL: GET /v1/me response data format invalid:', data);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: GET /v1/me returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: GET /v1/me request failed: ${err.message}`);
    allPassed = false;
  }

  // 4. Call PATCH /v1/me (Update nickname)
  const updatedNickname = 'TestPlayer';
  try {
    const res = await fetch(`${baseUrl}/v1/me`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        nickname: updatedNickname,
      }),
    });

    if (res.status === 200) {
      const data = (await res.json()) as any;
      if (data && data.nickname === updatedNickname) {
        console.log('PASS: PATCH /v1/me updated nickname successfully');
      } else {
        console.error('FAIL: PATCH /v1/me response did not reflect updated nickname:', data);
        allPassed = false;
      }
    } else {
      const err = await res.text();
      console.error(`FAIL: PATCH /v1/me returned status ${res.status}: ${err}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: PATCH /v1/me request failed: ${err.message}`);
    allPassed = false;
  }

  // 5. Call GET /v1/me without token (Verify 401 Unauthorized)
  try {
    const res = await fetch(`${baseUrl}/v1/me`, {
      method: 'GET',
    });

    if (res.status === 401) {
      console.log('PASS: GET /v1/me without token was rejected with 401 Unauthorized');
    } else {
      console.error(`FAIL: GET /v1/me without token returned unexpected status ${res.status}`);
      allPassed = false;
    }
  } catch (err: any) {
    console.error(`FAIL: GET /v1/me unauthorized check request failed: ${err.message}`);
    allPassed = false;
  }

  if (!allPassed) {
    process.exit(1);
  }
}

run();
