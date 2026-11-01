# Testing online play on localhost

No Firebase account is needed. The server's `DEV_AUTH=true` mode accepts a
token of the form `dev-<name>` as the user, and the Flutter **debug** build
sends one for you. Never enable `DEV_AUTH` in production (the server refuses
to start with `NODE_ENV=production`).

## 1. Database
Any Postgres works. Create a database and migrate it:

```bash
cd server
npm install
export DATABASE_URL=postgresql://postgres:PASSWORD@localhost:5432/homies_dev
npm run migrate:up
```

## 2. API server
```bash
cd server
DEV_AUTH=true DATABASE_URL=$DATABASE_URL npm run dev     # http://localhost:3000
# optional moderation API:  ADMIN_TOKEN=some-long-secret-123  (header x-admin-token)
```

## 3. The app (two players)
Use Chrome, one tab per player. The tab picks its player from `?dev=<name>`:

```bash
flutter run -d web-server --web-port 8090 --web-hostname localhost
```
Open `http://localhost:8090/?dev=alice` and `http://localhost:8090/?dev=bob`
(use a private window for the second if the tabs interfere).

Desktop/mobile builds can set the player with
`--dart-define=DEV_UID=alice`. On a physical phone also pass
`--dart-define=BACKEND_URL=http://<your-pc-lan-ip>:3000`.

## 4. Things to try
1. Alice: **Online Lobby, Create Room**. Bob: join with the code. Both **Ready Up**, Alice **Start Game**.
2. Roll alternately. Only the player whose turn it is can roll; the server picks the dice.
3. Leave the game screen, then **Return to game** from the lobby.
4. **Friends tab, Recent**: add Bob as a friend; Bob accepts under **Requests**.
5. Block, report, **Account** (rename, delete).

## 5. Quick Match and reactions
Quick Match ships **off**. Start the server with `FEATURE_PUBLIC_DISCOVERY=true` to try it; without it the Party tab shows the tile disabled and the server refuses searches. You can also flip it while running: `curl -X POST -H "x-admin-token: <ADMIN_TOKEN>" -H "Content-Type: application/json" -d '{"enabled":true}' localhost:3000/admin/flags/publicDiscovery`.

The first time a new player opens a private room or Quick Match they see the community rules and pick an age range. Under 13: private rooms only (no friend requests, no Quick Match).

1. Alice and Bob each open **Party, Quick match**, pick **Ludo**, **Connect Four** or **Snakes & Ladders**.
2. Whoever searches second is matched instantly; both land in a started game. Waiting alone times out after 60 s (set `MATCH_TIMEOUT_MS` on the server to change it).
3. Tap the emoji row or a quick phrase under the board; the other player sees it for a few seconds.
4. Host controls: in a lobby the host sees a remove button beside other players; a removed player cannot rejoin that room. Lobbies nobody starts close after 45 minutes.
5. Walk away: close one player's app mid-game. After 90 seconds the server forfeits them and the other player wins. An idle turn is skipped by the server after its deadline even if nobody is looking.
6. See what happened: `curl -H "x-admin-token: <ADMIN_TOKEN>" "localhost:3000/admin/stats?days=1"` (start the server with `ADMIN_TOKEN=...`).

## 6. Party Mode
1. Alice creates a room, picks **🎉 Party (random games)** and 3 rounds. Bob (and Carol) join with the code, everyone taps ready, Alice starts.
2. A random game opens, with the party score bar on top. Finish it; tap **Next round**: everyone moves to a different random game. With exactly 2 players Connect Four can come up; with 3-4 it cannot.
3. After the last round the bar names the winner.

## 7. Word Rush and Bluff & Vote
- **Word Rush** (2-4 players): create a room, pick Word Rush. Everyone sees the same scrambled letters; type the word. The first right answer scores; 5 rounds.
- **Bluff & Vote** (3 or 4 players, so open three browser windows): write a believable fake, then vote for the one you think is true. It does not appear in Quick Match.

## Automated checks
```bash
cd server
npm run typecheck && npm run test:snl && npm run test:ratelimit && npm run test:games && npm run test:ludo && npm run test:matchmaking && npm run test:party && npm run test:wordbluff
DATABASE_URL=... npm run test:integration   # real server + DB, Firebase stubbed
```
