/// Represents an authenticated user profile returned from the backend.
class UserProfile {
  final String id;
  final String? firebaseUid;
  final String nickname;
  final String? avatar;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.firebaseUid,
    required this.nickname,
    this.avatar,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      firebaseUid: json['firebase_uid'] as String?,
      nickname: json['nickname'] as String? ?? 'Guest',
      avatar: json['avatar'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'nickname': nickname,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? firebaseUid,
    String? nickname,
    String? avatar,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
