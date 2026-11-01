/// A player as shown in friends, requests, recent players and block lists.
/// [relation] is one of: friend, pending_in, pending_out, none, blocked.
class SocialPlayer {
  final String userId;
  final String nickname;
  final String? avatar;
  final String relation;

  /// Set only for rows in the friend-request lists.
  final String? requestId;

  const SocialPlayer({
    required this.userId,
    required this.nickname,
    this.avatar,
    this.relation = 'none',
    this.requestId,
  });

  factory SocialPlayer.fromJson(Map<String, dynamic> json) => SocialPlayer(
    userId: json['userId'] as String? ?? '',
    nickname: json['nickname'] as String? ?? 'Player',
    avatar: json['avatar'] as String?,
    relation: json['relation'] as String? ?? 'none',
    requestId: json['requestId'] as String?,
  );

  static List<SocialPlayer> listFrom(dynamic raw) => raw is List
      ? raw
            .whereType<Map>()
            .map((m) => SocialPlayer.fromJson(Map<String, dynamic>.from(m)))
            .toList()
      : <SocialPlayer>[];
}

/// Pending friend requests for the current user.
class FriendRequests {
  final List<SocialPlayer> incoming;
  final List<SocialPlayer> outgoing;
  const FriendRequests({this.incoming = const [], this.outgoing = const []});
}

/// Reasons accepted by the server for `POST /v1/reports`.
const reportReasons = <String, String>{
  'harassment': 'Harassment or abuse',
  'cheating': 'Cheating',
  'inappropriate_name': 'Inappropriate name',
  'spam': 'Spam',
  'other': 'Something else',
};
