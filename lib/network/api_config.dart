import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration for backend API and Socket.IO connections.
///
/// Provides default connection URLs for various platforms and supports overrides
/// via `--dart-define=BACKEND_URL=http://your-ip:3000` at compile/run time,
/// or dynamically via [setBaseUrl] at runtime.
///
/// Platform Guidelines:
/// - **Windows / macOS / Linux**: Uses `http://127.0.0.1:3000`.
/// - **Android Emulator**: Uses `http://10.0.2.2:3000` (Android's loopback alias to host machine).
/// - **iOS Simulator**: Uses `http://127.0.0.1:3000`.
/// - **Physical Devices (Android / iOS)**: Cannot use localhost. Provide the local
///   LAN IP of the machine running the backend (e.g. `http://192.168.1.100:3000`)
///   or a tunnel URL (e.g. ngrok/Cloudflare Tunnel).
class ApiConfig {
  ApiConfig._();

  /// Compile-time environment override via `--dart-define=BACKEND_URL=...`
  static const String _envBackendUrl = String.fromEnvironment('BACKEND_URL');

  /// Runtime override, if changed by user or settings.
  static String? _customBaseUrl;

  /// Sets a custom backend base URL at runtime.
  static void setBaseUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _customBaseUrl = trimmed;
  }

  /// Detects the appropriate default backend URL based on current operating platform.
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    try {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          // 10.0.2.2 routes directly to host 127.0.0.1 in standard Android emulator
          return 'http://10.0.2.2:3000';
        }
        if (Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isWindows ||
            Platform.isLinux) {
          return 'http://127.0.0.1:3000';
        }
      }
    } catch (_) {
      // Fallback for edge cases
    }

    return 'http://127.0.0.1:3000';
  }

  /// The active base URL for backend HTTP and Socket.IO connections.
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_envBackendUrl.isNotEmpty) {
      return _envBackendUrl;
    }
    return defaultBaseUrl;
  }

  // REST API Routes
  static String get guestAuthUrl => '$baseUrl/v1/auth/guest';
  static String get meUrl => '$baseUrl/v1/me';
  static String get roomsUrl => '$baseUrl/v1/rooms';
  static String get joinRoomUrl => '$baseUrl/v1/rooms/join';
  static String roomDetailsUrl(String code) => '$baseUrl/v1/rooms/$code';
  static String roomReadyUrl(String code) => '$baseUrl/v1/rooms/$code/ready';
  static String roomLeaveUrl(String code) => '$baseUrl/v1/rooms/$code/leave';
  static String roomStartUrl(String code) => '$baseUrl/v1/rooms/$code/start';
}
