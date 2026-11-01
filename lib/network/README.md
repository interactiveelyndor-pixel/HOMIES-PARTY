# Homies Party - Flutter Network Integration Layer

This directory (`lib/network/`) provides the client-side networking foundation connecting the Flutter board game suite to the Fastify + PostgreSQL + Socket.IO backend.

---

## 1. Architecture Overview

- **`api_config.dart`**: Centralized backend URL configuration with automated platform detection (Android Emulator `10.0.2.2`, Windows/iOS `127.0.0.1`) and runtime override capabilities.
- **`auth_service.dart`**: Handles guest authentication using Firebase Authentication. Extracts the Firebase ID token and passes it to the backend (`Bearer <idToken>`). Supports native Firebase Auth as well as REST API fallback for platforms without native Google Services configuration.
- **`api_client.dart`**: Typed HTTP client exposing REST methods for room creation, joining, ready states, leaving, starting, and profile retrieval/updating.
- **`socket_service.dart`**: Real-time Socket.IO client managing handshake authentication, room channel subscriptions (`room:subscribe`, `room:unsubscribe`), and listening for `room:updated` and `room:started` events.
- **`models/`**: Strongly-typed immutable models:
  - `UserProfile`: Backend user account.
  - `Room`: Game room state, codes, host, status (`lobby`/`playing`), player count, and participant lists.
  - `RoomPlayer`: Room participant representation including ready state and host flag.
  - `LeaveRoomResult`: Outcome of leaving a room (including host migration or empty-room deletion).

---

## 2. Platform URL Configuration

When testing or running the app:

| Platform | Default URL | Notes |
| :--- | :--- | :--- |
| **Windows Desktop** | `http://127.0.0.1:3000` | Works directly on local machine. |
| **Android Emulator** | `http://10.0.2.2:3000` | Automated loopback alias to host machine. |
| **iOS Simulator** | `http://127.0.0.1:3000` | Shares macOS host network stack. |
| **Physical Phone (Android/iOS)** | `http://<LAN-IP>:3000` | Use your development PC's Wi-Fi IP (e.g. `http://192.168.1.100:3000`) or a tunnel. |

### Overriding the URL:
1. **Compile/Run time flag:**
   ```bash
   flutter run --dart-define=BACKEND_URL=http://192.168.1.100:3000
   ```
2. **At runtime in the app:**
   Tap the settings icon in the top right of the **Online Multiplayer Lobby** screen to enter a custom backend address dynamically.

---

## 3. Running & Validating Tests

### Flutter Analysis & Unit Tests
```bash
# Verify static analysis
flutter analyze

# Run network and navigation tests
flutter test test/network_test.dart test/home_screen_test.dart
```

### Backend Integration
Ensure the backend is running in `server/`:
```bash
cd server
npm run dev
```
