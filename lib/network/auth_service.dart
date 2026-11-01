import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import 'models/user_profile.dart';

/// Exception thrown when authentication operations fail.
class AuthException implements Exception {
  final String message;
  final dynamic cause;

  const AuthException(this.message, [this.cause]);

  @override
  String toString() =>
      'AuthException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Service managing guest authentication with Firebase and the backend.
///
/// Follows the backend contract:
/// 1. Signs in anonymously via Firebase Auth (or REST fallback when native Firebase is unconfigured).
/// 2. Retrieves the Firebase ID token.
/// 3. Sends the token as `Bearer <token>` to the backend (`POST /v1/auth/guest`).
/// 4. Stores the resulting backend [UserProfile].
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Optional Firebase Web API Key override for platforms without native Firebase setup
  /// (e.g. Windows desktop), provided via `--dart-define=FIREBASE_WEB_API_KEY=...`.
  static const String _envWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static String? _customWebApiKey;

  static void setWebApiKey(String key) {
    _customWebApiKey = key.trim();
  }

  static String get webApiKey {
    if (_customWebApiKey != null && _customWebApiKey!.isNotEmpty) {
      return _customWebApiKey!;
    }
    return _envWebApiKey;
  }

  String? _cachedIdToken;
  DateTime? _tokenExpiry;
  UserProfile? _currentProfile;
  String? _initError;

  UserProfile? get currentProfile => _currentProfile;
  bool get isSignedIn => _cachedIdToken != null;
  String? get initError => _initError;

  void setInitError(String error) {
    _initError = error;
  }

  void setProfile(UserProfile profile) {
    _currentProfile = profile;
  }

  static const String _envDevUid = String.fromEnvironment('DEV_UID');

  /// Local-testing identity for a server started with DEV_AUTH=true. Debug
  /// builds only: `--dart-define=DEV_UID=alice`, or on web `/?dev=alice`
  /// (one name per browser tab).
  static String? get devUid {
    if (!kDebugMode) return null;
    final raw = _envDevUid.isNotEmpty
        ? _envDevUid
        : (kIsWeb ? Uri.base.queryParameters['dev'] : null);
    return raw != null && RegExp(r'^[A-Za-z0-9_-]{1,20}$').hasMatch(raw)
        ? raw
        : null;
  }

  /// Retrieves a valid Firebase ID token, refreshing if necessary.
  Future<String> getIdToken({bool forceRefresh = false}) async {
    final dev = devUid;
    if (dev != null) {
      _cachedIdToken = 'dev-$dev';
      _tokenExpiry = DateTime.now().add(const Duration(days: 1));
      return _cachedIdToken!;
    }

    // If we have an active non-expired token and no refresh requested, return it.
    if (!forceRefresh &&
        _cachedIdToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedIdToken!;
    }

    // 1. Native FirebaseAuth anonymous sign-in as the main path (when Firebase is initialized)
    if (Firebase.apps.isNotEmpty) {
      try {
        final auth = FirebaseAuth.instance;
        User? user = auth.currentUser;
        if (user == null) {
          final credential = await auth.signInAnonymously();
          user = credential.user;
        }

        if (user != null) {
          final token = await user.getIdToken(forceRefresh);
          if (token != null && token.isNotEmpty) {
            _cachedIdToken = token;
            _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
            return token;
          }
        }
        throw const AuthException('Firebase Auth did not return an ID token.');
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Native Firebase Auth failed: $e', e);
      }
    }

    // 2. REST fallback ONLY if Firebase is not initialized
    final apiKey = webApiKey;
    if (apiKey.isNotEmpty) {
      final token = await _signUpAnonymousRest(apiKey);
      _cachedIdToken = token;
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
      return token;
    }

    if (_cachedIdToken != null) {
      return _cachedIdToken!;
    }

    if (_initError != null && _initError!.isNotEmpty) {
      throw AuthException('Firebase initialization error: $_initError');
    }

    throw const AuthException(
      'Firebase is not initialized. Please configure Firebase to access the online lobby.',
    );
  }

  /// Fallback anonymous sign-up using the Firebase Identity Toolkit REST API.
  Future<String> _signUpAnonymousRest(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'returnSecureToken': true}),
      );

      if (response.statusCode != 200) {
        throw AuthException(
          'Firebase REST signup failed (${response.statusCode}): ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = data['idToken'] as String?;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Firebase REST signup did not return an idToken.',
        );
      }

      return idToken;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(
        'Failed to communicate with Firebase Auth REST API',
        e,
      );
    }
  }

  /// Clears active credentials.
  void signOut() {
    _cachedIdToken = null;
    _tokenExpiry = null;
    _currentProfile = null;
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }
}
