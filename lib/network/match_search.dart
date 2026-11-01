import 'dart:async';

import 'models/room.dart';

/// The player pressed Cancel while searching.
class MatchCancelled implements Exception {
  const MatchCancelled();
  @override
  String toString() => 'MatchCancelled';
}

/// A running Quick Match search. [room] completes with the started room when
/// another player is found; it fails with an ApiException on timeout or error,
/// or with [MatchCancelled] after [cancel].
class MatchSearch {
  final Future<Room> room;
  final void Function() cancel;
  const MatchSearch(this.room, this.cancel);
}

/// What Quick Match needs from the real-time connection.
abstract class MatchSocket {
  MatchSearch findMatch(String gameType);
}
