import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import 'models/room.dart';
import 'models/social_player.dart';
import 'models/user_profile.dart';

/// Exception thrown when a backend API request fails.
class ApiException implements Exception {
  final int statusCode;
  final String error;
  final String message;

  /// Machine-readable reason from the server, e.g. `CONSENT_REQUIRED`.
  final String? code;

  const ApiException({
    required this.statusCode,
    required this.error,
    required this.message,
    this.code,
  });

  @override
  String toString() => 'ApiException ($statusCode $error): $message';
}

/// HTTP client for interacting with the backend REST endpoints.
class ApiClient {
  final AuthService _authService;
  final http.Client _httpClient;

  ApiClient({AuthService? authService, http.Client? httpClient})
    : _authService = authService ?? AuthService(),
      _httpClient = httpClient ?? http.Client();

  /// Builds authorization headers using the current Firebase ID token.
  Future<Map<String, String>> _headers() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Parses error responses or throws an [ApiException].
  ApiException _parseError(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ApiException(
        statusCode: statusCode,
        error: json['error'] as String? ?? 'Error',
        message: json['message'] as String? ?? body,
        code: json['code'] as String?,
      );
    } catch (_) {
      return ApiException(
        statusCode: statusCode,
        error: 'HttpError',
        message: body.isNotEmpty
            ? body
            : 'Request failed with status $statusCode',
      );
    }
  }

  // --- Profile & Authentication ---

  /// Registers or retrieves a guest profile on the backend (`POST /v1/auth/guest`).
  Future<UserProfile> authenticateGuest() async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.guestAuthUrl),
      headers: headers,
      body: jsonEncode({}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      _authService.setProfile(profile);
      return profile;
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Fetches the authenticated user's profile (`GET /v1/me`).
  Future<UserProfile> getProfile() async {
    final headers = await _headers();
    final response = await _httpClient.get(
      Uri.parse(ApiConfig.meUrl),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      _authService.setProfile(profile);
      return profile;
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Updates the authenticated user's nickname and/or avatar (`PATCH /v1/me`).
  Future<UserProfile> updateProfile({String? nickname, String? avatar}) async {
    final headers = await _headers();
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatar != null) body['avatar'] = avatar;

    final response = await _httpClient.patch(
      Uri.parse(ApiConfig.meUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final profile = UserProfile.fromJson(json);
      _authService.setProfile(profile);
      return profile;
    }

    throw _parseError(response.statusCode, response.body);
  }

  // --- Room Operations ---

  /// Creates a new room with a short code (`POST /v1/rooms`).
  Future<Room> createRoom({
    int? maxPlayers,
    String? gameType,
    bool party = false,
    int? rounds,
  }) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomsUrl),
      headers: headers,
      body: jsonEncode({
        'maxPlayers': ?maxPlayers,
        'gameType': ?gameType,
        if (party) 'party': true,
        if (party) 'rounds': ?rounds,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Joins an existing room by code (`POST /v1/rooms/join`).
  Future<Room> joinRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.joinRoomUrl),
      headers: headers,
      body: jsonEncode({'code': code.trim()}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Fetches the details and player list for a room (`GET /v1/rooms/:code`).
  Future<Room> getRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.get(
      Uri.parse(ApiConfig.roomDetailsUrl(code.trim().toUpperCase())),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Updates the player's readiness state in a room (`POST /v1/rooms/:code/ready`).
  Future<Room> setReady(String code, bool ready) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomReadyUrl(code.trim().toUpperCase())),
      headers: headers,
      body: jsonEncode({'ready': ready}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  /// Leaves a room (`POST /v1/rooms/:code/leave`).
  Future<LeaveRoomResult> leaveRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomLeaveUrl(code.trim().toUpperCase())),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return LeaveRoomResult.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }

  // --- Social: friends, blocks, reports ---

  /// Sends [method] to [path] and returns the decoded JSON object.
  /// Throws [ApiException] unless the status is 2xx.
  Future<Map<String, dynamic>> _call(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final request = http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))
      ..headers.addAll(await _headers());
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _httpClient.send(request),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    }
    throw _parseError(response.statusCode, response.body);
  }

  /// Public, no sign-in needed: terms version, minimum app version, feature flags.
  Future<AppConfig> getConfig() async {
    final response = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/v1/config'),
    );
    if (response.statusCode == 200) {
      return AppConfig.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw _parseError(response.statusCode, response.body);
  }

  Future<Eligibility> getEligibility() async =>
      Eligibility.fromJson(await _call('GET', '/v1/me/eligibility'));

  /// Records acceptance of the current terms and the player's age range.
  Future<Eligibility> acceptConsent(String policyVersion, String ageBand) async =>
      Eligibility.fromJson(
        await _call('POST', '/v1/me/consent', {
          'policyVersion': policyVersion,
          'ageBand': ageBand,
        }),
      );

  Future<Progress> getProgress() async =>
      Progress.fromJson(await _call('GET', '/v1/me/progress'));

  /// Everything the server holds about the signed-in player.
  Future<Map<String, dynamic>> exportMyData() => _call('GET', '/v1/me/export');

  /// Host only: removes [userId] from a lobby.
  Future<Room> kickPlayer(String code, String userId) async => Room.fromJson(
    await _call('POST', '/v1/rooms/${code.trim().toUpperCase()}/kick', {
      'userId': userId,
    }),
  );

  /// Permanently deletes the signed-in account (`POST /v1/me/delete`).
  Future<void> deleteAccount() =>
      _call('POST', '/v1/me/delete', {'confirm': true});

  Future<List<SocialPlayer>> getFriends() async =>
      SocialPlayer.listFrom((await _call('GET', '/v1/friends'))['friends']);

  Future<List<SocialPlayer>> getRecentPlayers() async => SocialPlayer.listFrom(
    (await _call('GET', '/v1/players/recent'))['players'],
  );

  Future<FriendRequests> getFriendRequests() async {
    final json = await _call('GET', '/v1/friends/requests');
    return FriendRequests(
      incoming: SocialPlayer.listFrom(json['incoming']),
      outgoing: SocialPlayer.listFrom(json['outgoing']),
    );
  }

  /// Returns `pending`, or `friends` if the other player had already asked.
  Future<String> sendFriendRequest(String userId) async =>
      (await _call('POST', '/v1/friends/requests', {
            'userId': userId,
          }))['status']
          as String? ??
      'pending';

  Future<void> acceptFriendRequest(String requestId) =>
      _call('POST', '/v1/friends/requests/$requestId/accept');

  /// Declines (recipient) or cancels (sender) a pending request.
  Future<void> removeFriendRequest(String requestId) =>
      _call('DELETE', '/v1/friends/requests/$requestId');

  Future<void> removeFriend(String userId) =>
      _call('DELETE', '/v1/friends/$userId');

  Future<List<SocialPlayer>> getBlocked() async =>
      SocialPlayer.listFrom((await _call('GET', '/v1/blocks'))['blocked']);

  Future<void> blockUser(String userId) =>
      _call('POST', '/v1/blocks', {'userId': userId});

  Future<void> unblockUser(String userId) =>
      _call('DELETE', '/v1/blocks/$userId');

  Future<void> reportUser(String userId, String reason, {String? details}) =>
      _call('POST', '/v1/reports', {
        'userId': userId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      });

  /// Starts the game in the room (Host only, `POST /v1/rooms/:code/start`).
  Future<Room> startRoom(String code) async {
    final headers = await _headers();
    final response = await _httpClient.post(
      Uri.parse(ApiConfig.roomStartUrl(code.trim().toUpperCase())),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Room.fromJson(json);
    }

    throw _parseError(response.statusCode, response.body);
  }
}

/// What the server says the app may offer right now.
class AppConfig {
  final String policyVersion;
  final String minClientVersion;
  final bool publicDiscovery;

  const AppConfig({
    required this.policyVersion,
    required this.minClientVersion,
    required this.publicDiscovery,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    policyVersion: '${json['policyVersion'] ?? '1'}',
    minClientVersion: '${json['minClientVersion'] ?? '0.0.0'}',
    publicDiscovery:
        (json['features'] as Map?)?['publicDiscovery'] == true,
  );
}

/// What the signed-in player may do, based on consent and age range.
class Eligibility {
  final bool consented;
  final String? ageBand;
  final bool online;
  final bool social;
  final String policyVersion;

  const Eligibility({
    required this.consented,
    required this.ageBand,
    required this.online,
    required this.social,
    required this.policyVersion,
  });

  factory Eligibility.fromJson(Map<String, dynamic> json) => Eligibility(
    consented: json['consented'] == true,
    ageBand: json['ageBand'] as String?,
    online: json['online'] == true,
    social: json['social'] == true,
    policyVersion: '${json['policyVersion'] ?? '1'}',
  );
}

/// Level and XP earned from finished online games.
class Progress {
  final int xp, level, levelStartXp, nextLevelXp, played, wins;
  const Progress({
    required this.xp,
    required this.level,
    required this.levelStartXp,
    required this.nextLevelXp,
    required this.played,
    required this.wins,
  });

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    level: (j['level'] as num?)?.toInt() ?? 1,
    levelStartXp: (j['levelStartXp'] as num?)?.toInt() ?? 0,
    nextLevelXp: (j['nextLevelXp'] as num?)?.toInt() ?? 50,
    played: (j['played'] as num?)?.toInt() ?? 0,
    wins: (j['wins'] as num?)?.toInt() ?? 0,
  );

  /// 0..1 progress through the current level.
  double get fraction => nextLevelXp <= levelStartXp
      ? 0
      : ((xp - levelStartXp) / (nextLevelXp - levelStartXp)).clamp(0, 1);
}
