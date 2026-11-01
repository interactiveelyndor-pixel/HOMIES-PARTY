import 'room_player.dart';

/// Represents an online game room/lobby.
class Room {
  final String id;
  final String code;
  final String hostUserId;
  final String status;
  final int maxPlayers;
  final DateTime createdAt;
  final List<RoomPlayer> players;
  final String gameType;

  /// Server-authoritative game state (null until the game starts).
  final Map<String, dynamic>? gameState;

  /// Party Mode schedule and scores; null for ordinary rooms.
  final Map<String, dynamic>? party;

  const Room({
    required this.id,
    required this.code,
    required this.hostUserId,
    required this.status,
    required this.maxPlayers,
    required this.createdAt,
    required this.players,
    this.gameType = 'snl',
    this.gameState,
    this.party,
  });

  bool get isLobby => status == 'lobby';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isFull => players.length >= maxPlayers;

  bool isUserHost(String userId) => hostUserId == userId;

  RoomPlayer? getPlayer(String userId) {
    try {
      return players.firstWhere((p) => p.userId == userId || p.id == userId);
    } catch (_) {
      return null;
    }
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'];
    final playersList = <RoomPlayer>[];

    if (rawPlayers is List) {
      for (final item in rawPlayers) {
        if (item is Map<String, dynamic>) {
          playersList.add(RoomPlayer.fromJson(item));
        }
      }
    }

    return Room(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      hostUserId:
          json['hostUserId'] as String? ??
          json['host_user_id'] as String? ??
          '',
      status: json['status'] as String? ?? 'lobby',
      maxPlayers: (json['maxPlayers'] ?? json['max_players']) as int? ?? 4,
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.tryParse(
                  (json['createdAt'] ?? json['created_at']).toString(),
                ) ??
                DateTime.now()
          : DateTime.now(),
      players: playersList,
      gameType: json['gameType'] as String? ?? 'snl',
      gameState: json['gameState'] is Map
          ? Map<String, dynamic>.from(json['gameState'] as Map)
          : null,
      party: json['party'] is Map
          ? Map<String, dynamic>.from(json['party'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'hostUserId': hostUserId,
      'status': status,
      'maxPlayers': maxPlayers,
      'createdAt': createdAt.toIso8601String(),
      'players': players.map((p) => p.toJson()).toList(),
    };
  }
}

/// Result returned when leaving a room.
class LeaveRoomResult {
  final String message;
  final bool roomDeleted;
  final bool? newHostAssigned;
  final Room? room;

  const LeaveRoomResult({
    required this.message,
    required this.roomDeleted,
    this.newHostAssigned,
    this.room,
  });

  factory LeaveRoomResult.fromJson(Map<String, dynamic> json) {
    return LeaveRoomResult(
      message: json['message'] as String? ?? 'Left room successfully.',
      roomDeleted: json['roomDeleted'] == true,
      newHostAssigned: json['newHostAssigned'] as bool?,
      room: json['room'] != null && json['room'] is Map<String, dynamic>
          ? Room.fromJson(json['room'] as Map<String, dynamic>)
          : null,
    );
  }
}
