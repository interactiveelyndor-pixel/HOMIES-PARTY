# Build Log

## Step 1 - Project inspection
- **What was done:** Inspected the overall repository structure, Flutter application code in `lib/`, game modules, `pubspec.yaml`, toolchains, and verified whether any backend service existed.
- **What changed in the project:** Nothing changed (inspection only).
- **Findings:**
  - 5 games found (Dots & Boxes, Carrom, Pen Fight, Air Hockey, Ludo).
  - Flutter without Flame engine (built using standard Flutter widgets, CustomPainter, and AnimationController/Ticker physics).
  - No backend service was present.
  - Node, npm, and Git are installed on the machine.

## Step 2 - Backend foundation
- **What was done:** Initialized and set up a Node.js + TypeScript backend inside the `server/` directory. Created the following files:
  - `server/package.json` - Project metadata, scripts (`dev`, `build`, `typecheck`, `start`, `migrate:up`, `migrate:down`), and dependencies (`fastify`, `pg`, `dotenv`, `tsx`, `typescript`, `node-pg-migrate`).
  - `server/package-lock.json` - Locked dependency tree.
  - `server/tsconfig.json` - TypeScript compiler configuration.
  - `server/.gitignore` - Git ignore rules for `node_modules`, `dist`, and `.env`.
  - `server/.env.example` - Environment variable template defining `PORT` and `DATABASE_URL`.
  - `server/src/server.ts` - Fastify server setup exposing `/health` and `/health/db` endpoints.
  - `server/src/db.ts` - PostgreSQL client connection pool using `pg`.
  - `server/migrations/1792611799879_initial-tables.sql` - Database migration script for initial schema tables.
- **What changed in the project:**
  - The standalone backend service now runs successfully.
  - Fastify server starts and listens on `http://0.0.0.0:3000`.
  - `GET /health` returns `{ "status": "ok", "app": "Homies Party Backend" }`.
  - `GET /health/db` provides database connectivity checks.
  - TypeScript compilation and type checking pass without errors.
- **How to test:**
  1. Open a terminal and navigate to `server/`:
     ```bash
     cd server
     ```
  2. Install dependencies (if not already installed):
     ```bash
     npm install
     ```
  3. Run TypeScript type check:
     ```bash
     npm run typecheck
     ```
  4. Start the development server:
     ```bash
     npm run dev
     ```
  5. In another terminal window or browser, test the health endpoint:
     ```bash
     curl http://localhost:3000/health
     ```
     Expected response:
     ```json
     {"status":"ok","app":"Homies Party Backend"}
     ```

## Step 3 - Database setup
- **What was done:**
  - Integrated PostgreSQL using the `pg` client library and `node-pg-migrate` for SQL-based migrations.
  - Implemented `server/src/db.ts` to create and export a shared PostgreSQL connection `Pool` using `DATABASE_URL` loaded from `.env` via `dotenv`.
  - Created migration file `server/migrations/001_initial_tables.sql` establishing 3 relational tables:
    - `users` (id uuid pk, firebase_uid text unique nullable, nickname text, avatar text, created_at)
    - `rooms` (id uuid pk, code text unique, host_user_id fk users, status text default 'lobby', max_players int, created_at)
    - `room_players` (room_id fk, user_id fk, is_ready bool default false, joined_at, primary key (room_id, user_id))
  - Configured npm scripts in `server/package.json`:
    - `npm run migrate:up`: Executes pending database migrations.
    - `npm run migrate:down`: Reverts applied database migrations.
  - Added route `GET /health/db` in `server/src/server.ts` that executes `SELECT 1` on the pool and returns `{ "db": "ok" }` on success or HTTP 500 with error details on failure.
  - Configured `server/.env.example` with `DATABASE_URL=postgresql://postgres:PASSWORD@localhost:5432/homies_party`.
- **What changed in the project:**
  - The backend server can now connect to PostgreSQL and query the database.
  - Database schema can now be tracked, applied, and rolled back deterministically using migration scripts.
  - Relational schema for players, game rooms, and lobby participant states is provisioned in the database.
  - Real-time DB connectivity can be monitored via the `GET /health/db` endpoint.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Verify TypeScript types:
     ```bash
     npm run typecheck
     ```
  3. Run database migrations:
     ```bash
     npm run migrate:up
     ```
  4. Start the dev server:
     ```bash
     npm run dev
     ```
  5. Test endpoints in a browser or terminal:
     - Health route:
       ```bash
       curl http://localhost:3000/health
       ```
       Returns:
       ```json
       {"status":"ok","app":"Homies Party Backend"}
       ```
     - Database health route:
       ```bash
       curl http://localhost:3000/health/db
       ```
       Returns:
       ```json
       {"db":"ok"}
       ```
  6. (Optional) Test rolling back migrations:
     ```bash
     npm run migrate:down
     ```

## Step 4 - Guest login (Firebase)
- **What was done:**
  - Added `secrets/` to `server/.gitignore` to protect service account keys and secrets.
  - Installed `firebase-admin` package for server-side token authentication.
  - Created `server/src/firebase.ts` to initialize Firebase Admin SDK using application default credentials (`GOOGLE_APPLICATION_CREDENTIALS`).
  - Created `server/src/auth.ts` providing an `authenticate` preHandler hook that validates the `Authorization: Bearer <token>` header with Firebase and returns HTTP 401 on missing or invalid tokens.
  - Added Fastify routes in `server/src/server.ts`:
    - `POST /v1/auth/guest`: Looks up the user by `firebase_uid`. If not found, creates a new user profile with nickname format `Guest<4 digits>` and returns the user object.
    - `GET /v1/me`: Returns the authenticated user's profile.
    - `PATCH /v1/me`: Allows updating the user's `nickname` (2-20 characters) and `avatar` (max 30 characters), returning HTTP 400 for invalid inputs.
  - Used parameterized SQL queries (`$1`, `$2`, etc.) across all database operations.
  - Redacted the `authorization` header in Fastify logging so tokens are never logged.
  - Added automated test script `server/scripts/test-guest.ts` and configured npm script `npm run test:guest`.
- **What changed in the project:**
  - Clients can now authenticate using Firebase ID tokens.
  - Anonymous/guest players can sign in and automatically receive a database profile.
  - Authenticated players can fetch and update their profile (`nickname` and `avatar`).
  - Protected endpoints reject unauthenticated or malformed requests with HTTP 401.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Run TypeScript check:
     ```bash
     npm run typecheck
     ```
  3. Start the dev server (if not already running):
     ```bash
     npm run dev
     ```
  4. Run the guest login automated test suite:
     ```bash
     npm run test:guest
     ```
     Expected output:
     ```
     PASS: POST /v1/auth/guest created/retrieved guest user
     PASS: GET /v1/me returned profile successfully
     PASS: PATCH /v1/me updated nickname successfully
     PASS: GET /v1/me without token was rejected with 401 Unauthorized
     ```
  5. Test unauthorized access manually using curl:
     ```bash
     curl http://localhost:3000/v1/me
     ```
     Returns HTTP 401:
     ```json
     {"error":"Unauthorized","message":"Missing or invalid Authorization header. Format must be Bearer <token>."}
     ```

## Step 5 - Online rooms
- **What was done:**
  - Implemented online room management in `server/src/rooms.ts` using existing database tables (`users`, `rooms`, `room_players`), connection pool, and `authenticate` preHandler.
  - Added 6-character room code generation using base32 character set `[A-Z2-9]` excluding ambiguous characters (`O`, `I`, `0`, `1`), with collision retry logic.
  - Implemented endpoints:
    - `POST /v1/rooms`: Creates a new room with configurable `maxPlayers` (2-4, default 4), sets status to `'lobby'`, adds the creator to `room_players` as host, and returns the room with players.
    - `POST /v1/rooms/join`: Case-insensitive room code join. Uses PostgreSQL row locking (`SELECT ... FOR UPDATE`) in a database transaction to prevent overfilling seats concurrently. Returns existing room if the user is already a member, 404 if not found, 409 if full or not in `'lobby'` status.
    - `GET /v1/rooms/:code`: Returns room details and player list (nickname, avatar, isReady, isHost). Accessible to room members only (403 for non-members).
    - `POST /v1/rooms/:code/ready`: Allows room members to toggle ready status (`{"ready": true/false}`).
    - `POST /v1/rooms/:code/leave`: Removes member from room. If host leaves, assigns the earliest-joined remaining player as host. If room becomes empty, deletes the room.
    - `POST /v1/rooms/:code/start`: Allows host to start the game. Requires at least 2 players and all players to be ready; updates status to `'playing'`.
  - Added strict input validation (returns HTTP 400 on invalid payload or params) and checked that logged-in Firebase users exist in the `users` table (HTTP 404 with clear message).
  - Ensured all database queries use parameterized SQL variables (`$1`, `$2`, etc.) and no tokens are logged.
  - Added automated test suite `server/scripts/test-rooms.ts` and configured npm script `"test:rooms": "tsx scripts/test-rooms.ts"`.
- **What changed in the project:**
  - The backend server can now host and orchestrate multiplayer game lobbies and rooms entirely through REST endpoints.
  - Players can create private rooms with short, human-friendly 6-character codes.
  - Players can join lobbies, toggle their readiness, and hosts can start games once all participants are ready.
  - Lobby membership is protected with transaction safety, seat limits, and member-only room visibility.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Run TypeScript compiler check:
     ```bash
     npm run typecheck
     ```
  3. Start the dev server (if not already running):
     ```bash
     npm run dev
     ```
  4. Run the automated rooms test suite:
     ```bash
     npm run test:rooms
     ```
     Real output:
     ```
     PASS: Registered guest users (User A, User B, User C)
     PASS: User A created room with code 'HVM99E' (status: lobby, creator is host)
     PASS: User B joined the room with case-insensitive code (2 players now in room)
     PASS: User A marked ready
     PASS: User B marked ready (both players ready)
     PASS: Host started the game successfully (status is playing)
     PASS: Third guest trying to join started room received 409 Conflict
     PASS: Non-member reading the room received 403 Forbidden
     PASS: Member reading the room returned room details and player list successfully
     PASS: Logged-in Firebase user without row in users received 404
     PASS: Invalid maxPlayers (5) rejected with 400 Bad Request
     PASS: Empty room code on join rejected with 400 Bad Request
     PASS: Host left room; earliest remaining player (User B) became new host
     PASS: Last player left room; room was deleted because it became empty
     ```

## Step 6 - Socket.IO real-time updates
- **What was done:**
  - Installed `socket.io` and `socket.io-client` (dev dependency).
  - Attached Socket.IO to the existing Fastify server (`server.server`) in `server/src/server.ts` so REST APIs and WebSockets share the same port.
  - Implemented connection authentication middleware in `server/src/socket.ts` that verifies Firebase ID tokens passed in `socket.handshake.auth.token` and checks that the user exists in PostgreSQL (`users` table). Rejects missing or invalid tokens and unregistered users without logging tokens.
  - Added Socket.IO room subscription handlers:
    - `"room:subscribe"`: Validates that the requesting socket's user is a member of the room; joins the socket to the room channel and returns the room's current state in the acknowledgement. Non-members or non-existent rooms are rejected.
    - `"room:unsubscribe"`: Removes the socket from the room channel.
    - Handled socket disconnect cleanup without dropping players from database rooms.
  - Integrated real-time broadcasts in `server/src/rooms.ts`:
    - Emits `"room:updated"` with the full room state to room members whenever a player joins, changes ready status, or leaves (including host migration).
    - Emits `"room:started"` when the host starts the game.
  - Added automated test suite `server/scripts/test-realtime.ts` and configured npm script `"test:realtime": "tsx scripts/test-realtime.ts"`.
- **What changed in the project:**
  - The server now supports bidirectional real-time communication alongside existing REST endpoints on the same port.
  - Clients subscribed to a room receive instant updates when participants join, change ready state, leave, or when the host starts the match.
  - Unauthorized or unauthenticated socket connections and subscriptions are strictly rejected.
- **How to test:**
  1. Navigate to `server/`:
     ```bash
     cd server
     ```
  2. Run TypeScript compiler check:
     ```bash
     npm run typecheck
     ```
  3. Start the dev server (if not already running):
     ```bash
     npm run dev
     ```
  4. Run the automated real-time test suite:
     ```bash
     npm run test:realtime
     ```
     Real output:
     ```
     PASS: Authenticated user can connect to Socket.IO
     PASS: Connection without a token was rejected
     PASS: Connection with invalid token was rejected
     PASS: Connection for user without DB profile was rejected
     PASS: Room member subscribed and received current room state
     PASS: Non-member subscription was rejected (403 Forbidden)
     PASS: Subscribed User A received "room:updated" when User B joined via REST
     PASS: Subscribed User A received "room:updated" when User B marked ready
     PASS: Subscribed members (User A and User B) received "room:started" event
     ```
  5. Run the full backend test suite to ensure zero regressions:
     ```bash
     npm run test:guest
     npm run test:rooms
     ```

## Step 7A - Flutter foundation for online multiplayer
- **What was done:**
  - Added required Flutter dependencies in `pubspec.yaml`: `http`, `socket_io_client`, `firebase_core`, and `firebase_auth`.
  - Built clean networking layer under `lib/network/`:
    - `api_config.dart`: Centralized backend base URL configuration with platform-specific defaults (Android Emulator `10.0.2.2`, Windows/iOS `127.0.0.1`), compile-time `--dart-define=BACKEND_URL=...` override, and runtime configuration settings.
    - `auth_service.dart`: Firebase guest authentication service. Obtains Firebase ID tokens via native Firebase Auth or REST API fallback, attaches credentials as `Bearer <token>`, and syncs with backend profile (`POST /v1/auth/guest`).
    - `api_client.dart`: Typed HTTP client implementing complete room operations (`createRoom`, `joinRoom`, `getRoom`, `setReady`, `leaveRoom`, `startRoom`) and user profile operations (`authenticateGuest`, `getProfile`, `updateProfile`).
    - `socket_service.dart`: Real-time Socket.IO client managing handshake authentication, room subscriptions (`room:subscribe`, `room:unsubscribe`), and streams for `room:updated` and `room:started`.
    - `models/`: Strongly typed models for `UserProfile`, `Room`, `RoomPlayer`, and `LeaveRoomResult`.
    - `network.dart`: Unified barrel export file.
  - Implemented standalone `OnlineLobbyScreen` (`lib/screens/online_lobby_screen.dart`) providing room creation, joining by code, ready status toggling, host-only game start, and live Socket.IO room sync.
  - Added minimal, non-disruptive entry point to `HomeScreen` via FloatingActionButton without modifying existing game layouts, assets, or controls.
  - Added unit test suite in `test/network_test.dart` and comprehensive setup/testing documentation in `lib/network/README.md`.
- **What changed in the project:**
  - Flutter app is now equipped with client-side networking and real-time infrastructure to communicate with the Homies Party backend.
  - Players can access an online multiplayer lobby interface, manage private room codes, and see live participant updates over Socket.IO.
  - All 5 existing local tabletop games (Ludo, Snakes & Ladders, Carrom, Battleship, Pen Fight) remain fully preserved with all tests passing.
- **How to test:**
  1. Run Flutter static analysis:
     ```bash
     flutter analyze
     ```
  2. Run Flutter test suite:
     ```bash
     flutter test test/network_test.dart test/home_screen_test.dart
     ```
  3. Run backend typecheck and tests:
     ```bash
     cd server
     npm run typecheck
     ```





## Step 7a - Verification
- **What was verified:**
  - Ran git diff --stat and confirmed zero modifications to existing game code (lib/logic/, lib/snl/, lib/carrom/, lib/battleship/, lib/pen_fight/, lib/models/, lib/widgets/, lib/ui/, lib/theme/). Only lib/screens/home_screen.dart was modified to add a FloatingActionButton leading to the online lobby.
  - Executed flutter pub get: Dependencies resolved successfully.
  - Executed flutter analyze: Passed with 0 errors or warnings.
  - Executed full flutter test suite: All 253 tests passed (0 failed).
  - Inspected lib/network/ and lib/screens/online_lobby_screen.dart to verify module responsibilities, server URL resolution, and confirmed no hardcoded keys, tokens, or credentials exist in the source code.
  - Audited Firebase setup and .gitignore coverage.

## Step 8 - Online Snakes & Ladders, timeouts, rematch
- Migration `002_room_game.sql` (additive): `rooms.game_type`, `rooms.game_state`.
- `src/snl.ts`: server-authoritative rules (mirrors the Dart game). Socket events `game:roll`, `game:skip` (30s turn deadline, server-verified), `game:rematch`. Server broadcasts `game:state`.
- Flutter: `OnlineSnlScreen`, opened by the lobby when the host starts.

## Step 9 - Friends, blocks, reports
- Migration `003_social.sql` (additive): `recent_players`, `friendships`, `friend_requests`, `blocks`, `reports`.
- `src/social.ts`: recent players, friend requests (mutual consent; crossing requests auto-accept), block (removes friendship/requests, hides both ways, blocks room joins in `rooms.ts`), report (reasons enum, 500 char details). Friend requests and reports only between players who shared a started game. Rate limits in `src/ratelimit.ts` (in-memory, per process).
- Flutter: Social tab (`SocialScreen`) with Friends / Requests / Recent / Blocked.
- Tests: `npm run test:snl`, `npm run test:ratelimit`, and `npm run test:integration` (real server + Postgres, Firebase token check stubbed; needs a migrated `DATABASE_URL`).
- Not built: text chat, push notifications (lists refresh on open / pull-to-refresh), moderation tooling to review `reports`, account deletion.

## Step 10 - Account deletion and moderation
- Migration `004_moderation.sql` (additive): `users.banned_at`; `reports.reporter_id` becomes nullable with ON DELETE SET NULL so reports survive reporter deletion.
- `POST /v1/me/delete { confirm: true }` (`src/account.ts`): removes the user and all social rows, passes hosted rooms to the next player, deletes the Firebase user best-effort.
- Suspension: `authenticate` refuses banned users on every route; sockets refuse them at connect and on every game action.
- Admin API (`src/admin.ts`) exists only when `ADMIN_TOKEN` (16+ chars) is set; header `x-admin-token`. `GET /admin/reports?status=open|all`, `POST /admin/reports/:id/resolve {status: dismissed|actioned}`, `POST /admin/users/:id/ban|unban`.
- Flutter: `AccountScreen` (rename, delete) opened from the Social tab.
- Known gaps: single shared admin secret and no audit log; no automated Firebase-orphan cleanup; no appeals flow; chat not built.

## Step 11 - Game framework + online Connect Four
- `src/games/` (`types.ts`, `registry.ts`, `connect4.ts`): a game is a module with `init`, `move`, `skip`. The room's `game_type` picks it. Snakes & Ladders keeps `src/snl.ts` behind an adapter. To add a game: write the module, add it to `GAMES`, add its screen to `lib/screens/online_game_router.dart`.
- Socket events: `game:move {code, move}` (generic), `game:roll` (older name, same path), `game:skip`, `game:rematch`. Status becomes `finished` on a win or a draw.
- Room limits come from the game (Connect Four is exactly 2 players).

## Step 12 - Quick Match
- `src/matchmaking.ts`: in-memory queue per game, one join at a time per game, skips disconnected and blocked players, times out (`MATCH_TIMEOUT_MS`, default 60s), cancels on disconnect. `createMatchedRoom` (rooms.ts) makes an already-started room.
- Socket events: `match:join {gameType}`, `match:cancel`; server sends `match:found {room}`, `match:timeout`, `match:error`. Rate limit 12 searches/minute/user.
- Limit: the queue is per process (restart empties it; one server only).

## Step 13 - Reactions
- `game:react {code, emoji}` from a fixed set (`REACTIONS` in socket.ts, mirrored in `lib/screens/online_reactions.dart`). Members only, 20 per 30s, never delivered to anyone who blocked the sender.

## Step 14 - Product events
- Migration `005_events.sql`. `src/events.ts` `logEvent()` is fire-and-forget. Events: match_searching, match_found, match_timeout, match_cancelled, game_started (source room|quick_match), game_finished (win|draw), rematch_started, friend_request_sent, friend_request_accepted.
- No names or text are stored; user_id becomes NULL when an account is deleted; rows older than 180 days are purged daily.
- `GET /admin/stats?days=7` (admin token) returns plain counts overall and per game.
- Not built: client-side events (app open, catalogue viewed) because there is no analytics provider or consent flow yet.

## Step 15 - Online Ludo
- `src/games/ludo.ts`: Ludo rules on the server (2-4 players, red/yellow, red/green/yellow, or all four). The server rolls; no input means "roll", `{token: id}` means "move this token"; mixing them up is rejected. A lone legal move is played automatically; an idle player's turn auto-plays their furthest token (or passes).
- Parity: `test/ludo_parity_fixture_test.dart` records games from the offline Dart controller into `server/scripts/fixtures/ludo_parity.json` (36 games); `npm run test:ludo` replays them through the server rules and compares every token after every turn (7,635 turns identical), plus rule tests and 120 random games with invariants. Regenerate the fixture with `GEN_LUDO_FIXTURE=1 flutter test test/ludo_parity_fixture_test.dart` if the offline rules ever change on purpose.
- App: `OnlineLudoScreen` reuses the offline board, dice and token widgets; it is available from private rooms (2-4 players) and Quick Match.

## Step 16 - Launch safety (Batch A)
- Migration `006_launch_controls.sql`: `users.age_band`, `user_consents`, `feature_flags`, `room_kicks`.
- `flags.ts`: `publicDiscovery` (env default `FEATURE_PUBLIC_DISCOVERY`, default off) with DB overrides via `POST /admin/flags/:key`. `GET /v1/config` is public.
- `eligibility.ts`: terms version `POLICY_VERSION`; creating/joining rooms needs consent (`CONSENT_REQUIRED`); friend requests and Quick Match need 13+ (`SOCIAL_NOT_ALLOWED`); under-13 answers cannot be changed. `GET /v1/me/export` (3/hour).
- `gameRuntime.ts`: one locked-transaction path for player actions and server-driven skips; optional `expectedRevision` rejects stale or repeated taps (`REVISION_CONFLICT`). Old clients that send none still work.
- `sweeper.ts` (every `SWEEP_MS`, default 5 s): skips expired turns, forfeits users disconnected longer than `DISCONNECT_GRACE_MS` (90 s), deletes lobbies older than `ROOM_EXPIRY_MINUTES` (45) and finished/stale games after 12 h. `DISABLE_SWEEPER=true` turns it off (tests).
- Host kick: `POST /v1/rooms/:code/kick`; lobby only; removed players cannot rejoin that room.
- Quick phrases join the reaction set (`PHRASES` in socket.ts, mirrored in `online_reactions.dart`); anything else is rejected.
- Known limits: presence, rate limiting and the matchmaking queue are in memory, so this is single-server; a restart forgets who was disconnected (they get a fresh 90 s). Room names were not added because free text would need moderation.

## Step 17 - Match XP
- Migration `007_xp_ledger.sql`. `progress.ts`: when a game ends (any path: a move, a skipped turn, a forfeit) `gameRuntime` pays XP inside the same transaction: win 30, draw 15, played 10, nothing for players who left. Unique key (user, room, game version) makes it idempotent; 300 XP/day cap per user. `GET /v1/me/progress` -> xp, level (`floor(sqrt(xp/50))+1`), wins, played. Included in the data export; deleted with the account.
- Limit: the cap is per user only; two friends trading wins in a private room can still reach it daily. Not built: Party Mode (needs a definition), a "+XP" banner at game end.

## Step 18 - Party Mode
- Migration `008_party_mode.sql` (`rooms.party` JSONB). `src/party.ts`: `pickGame` (random game that fits the group, never the same twice in a row when there is a choice; Connect Four only with exactly 2), `scoreRound` (win 3, played 1, draw 2, players who left 0).
- Create with `{party: true, rounds: 2-7}` (default 3, up to 4 players, no `gameType`). Starting draws round 1; when a round ends the score is saved in the same transaction and everyone gets `room:updated`. `game:rematch` in a party means "next round": new random game, `room:started` sent to all, refused before the game ends or after the last round.
- `test:party` (unit) and integration checks play a 2-round party end to end.
- Limits: the next round needs a tap from any player; if players left so that no game fits (1 player), the party cannot continue. Scores are not tied to XP beyond each game's normal XP.

## Step 19 - Word Rush and Bluff & Vote
- Games that everyone plays at once: `simultaneous: true` in the state (no "your turn"), phases and rounds run on `turnDeadline`, so the existing timers, sweeper and forfeit logic move them along. Shared helpers in `games/simultaneous.ts`.
- Hidden data: any state key starting with `_` (the word, the real answer, who wrote what, votes) is stripped by `publicState` before leaving the server: room details, `game:state` broadcasts and action replies. A game publishes it in a normal field when it should be revealed. Checked over real sockets in `test:integration`.
- Word Rush (2-4 players, 5 rounds, 30 s each, 5 guesses per player per round): first correct guess takes the round (3 points). Built-in list of 70 everyday words. Wrong guesses are never shown, so there is no player text to moderate.
- Bluff & Vote (3-4 players, 3 questions): write a fake answer (max 30 chars) -> vote -> reveal. Voting for the truth earns 2, each vote on your fake earns 1. Questions are built in (14). `privateOnly`: Quick Match refuses it (`PRIVATE_ONLY`); the reveal screen has a report button on each fake (sends the text with the report).
- Both join Party Mode's random pool where the group size fits.
- Limits: no profanity filter on fakes (reporting and private rooms are the safeguard); 14 questions and 70 words repeat quickly; Word Rush has no hint system; an answer equal to the truth is refused, which hints that the truth was guessed.
