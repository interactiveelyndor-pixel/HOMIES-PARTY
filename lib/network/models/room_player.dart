/// Represents a participant in an online room.
class RoomPlayer {
  final String id;
  final String userId;
  final String nickname;
  final String? avatar;
  final bool isReady;
  final bool isHost;
  final DateTime joinedAt;

  const RoomPlayer({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatar,
    required this.isReady,
    required this.isHost,
    required this.joinedAt,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id:
          json['id'] as String? ??
          json['userId'] as String? ??
          json['user_id'] as String? ??
          '',
      userId:
          json['userId'] as String? ??
          json['user_id'] as String? ??
          json['id'] as String? ??
          '',
      nickname: json['nickname'] as String? ?? 'Player',
      avatar: json['avatar'] as String?,
      isReady: json['isReady'] == true || json['is_ready'] == true,
      isHost: json['isHost'] == true || json['is_host'] == true,
      joinedAt: json['joinedAt'] != null || json['joined_at'] != null
          ? DateTime.tryParse(
                  (json['joinedAt'] ?? json['joined_at']).toString(),
                ) ??
                DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'nickname': nickname,
      'avatar': avatar,
      'isReady': isReady,
      'isHost': isHost,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}
