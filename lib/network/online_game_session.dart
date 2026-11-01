import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models/room.dart';

/// What an online game needs from the real-time connection. [SocketService]
/// implements it; tests use a fake.
abstract class GameSocket {
  Stream<Map<String, dynamic>> get onGameState;
  Stream<bool> get onConnectionStateChanged;
  Future<Room> subscribeToRoom(String code);
  Future<void> rollDice(String code, {int? expectedRevision});
  Future<void> move(
    String code,
    Map<String, dynamic> input, {
    int? expectedRevision,
  });
  Future<void> skipTurn(String code);
  Future<void> rematch(String code);
  Stream<Map<String, dynamic>> get onReaction;
  Future<void> react(String code, String emoji);
}

/// A reaction someone sent, shown briefly.
class Reaction {
  final int id;
  final String userId;
  final String emoji;
  const Reaction(this.id, this.userId, this.emoji);
}

/// Shared client side of a server-authoritative game (Snakes & Ladders,
/// Connect Four, ...). The server owns the state; this class only keeps a copy
/// in sync, forwards the player's inputs and reports expired turns.
class OnlineGameSession extends ChangeNotifier {
  final String myUserId;
  final GameSocket socket;

  /// Extra wait past a deadline before reporting it, to absorb clock skew.
  final Duration skipSlack;

  Room room;
  Map<String, dynamic> state;
  String? error;
  bool busy = false;

  StreamSubscription<Map<String, dynamic>>? _stateSub;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<Map<String, dynamic>>? _reactSub;
  Timer? _skipTimer;
  bool _disposed = false;

  /// Recent reactions (newest last); each disappears after [reactionLife].
  final List<Reaction> reactions = [];
  final Duration reactionLife;
  int _reactionSeq = 0;
  DateTime _lastReact = DateTime.fromMillisecondsSinceEpoch(0);

  OnlineGameSession({
    required this.room,
    required this.myUserId,
    required this.socket,
    this.skipSlack = const Duration(milliseconds: 300),
    this.reactionLife = const Duration(seconds: 3),
  }) : state = room.gameState! {
    _reactSub = socket.onReaction.listen((e) {
      final emoji = e['emoji'];
      final who = e['userId'];
      if (e['code'] != room.code || emoji is! String || who is! String) return;
      final r = Reaction(_reactionSeq++, who, emoji);
      reactions.add(r);
      if (reactions.length > 4) reactions.removeAt(0);
      notifyListeners();
      Timer(reactionLife, () {
        if (_disposed) return;
        reactions.remove(r);
        notifyListeners();
      });
    });
    _stateSub = socket.onGameState.listen((e) {
      if (e['code'] != room.code || e['state'] is! Map) return;
      _apply(Map<String, dynamic>.from(e['state'] as Map));
    });
    // A reconnect creates a new socket: re-join the room channel and resync.
    _connSub = socket.onConnectionStateChanged.listen((up) {
      if (up) resync();
    });
    _scheduleSkip();
    // The room passed in may be stale (e.g. returning to a game in progress).
    resync();
  }

  /// Label for the button that starts what comes next, or null when nothing
  /// does (the last round of a party). Ordinary rooms offer a rematch.
  String? get rematchLabel {
    final party = room.party;
    if (party == null) return 'Rematch';
    final round = (party['round'] as num?)?.toInt() ?? 0;
    final rounds = (party['rounds'] as num?)?.toInt() ?? 0;
    return round >= rounds ? null : 'Next round';
  }

  // --- derived state -------------------------------------------------------

  List<Map> get players => (state['players'] as List).cast<Map>();
  int get version => state['version'] as int;
  String? get winnerId => state['winnerId'] as String?;
  bool get isDraw => state['draw'] == true;
  bool get isOver => winnerId != null || isDraw;
  String get currentUserId => players[state['turn'] as int]['userId'] as String;
  bool get myTurn => !isOver && currentUserId == myUserId;

  /// Everyone plays at once (Word Rush, Bluff & Vote): there is no turn to wait for.
  bool get simultaneous => state['simultaneous'] == true;

  /// Index of [userId] in the player list, or -1.
  int indexOf(String? userId) =>
      players.indexWhere((p) => p['userId'] == userId);

  String nameOf(String? userId) =>
      room.getPlayer(userId ?? '')?.nickname ?? 'Player';

  // --- actions -------------------------------------------------------------

  /// Plays the current user's turn. With no [input] the server decides (it
  /// rolls the dice); otherwise [input] is the move, e.g. `{'column': 3}`.
  Future<void> act([Map<String, dynamic>? input]) async {
    if (busy || isOver || (!simultaneous && !myTurn)) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      // The revision lets the server refuse a tap made on an out-of-date board.
      if (input == null) {
        await socket.rollDice(room.code, expectedRevision: version);
      } else {
        await socket.move(room.code, input, expectedRevision: version);
      }
    } on ApiException catch (e) {
      error = e.message;
      if (e.code == 'REVISION_CONFLICT') unawaited(resync());
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Sends a reaction. Taps closer than half a second apart are ignored here;
  /// the server enforces the real limit.
  Future<void> react(String emoji) async {
    final now = DateTime.now();
    if (now.difference(_lastReact) < const Duration(milliseconds: 500)) return;
    _lastReact = now;
    try {
      await socket.react(room.code, emoji);
    } catch (_) {
      // A dropped reaction is not worth interrupting the game for.
    }
  }

  Future<void> rematch() async {
    try {
      await socket.rematch(room.code);
    } on ApiException catch (e) {
      error = e.message;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> resync() async {
    try {
      final fresh = await socket.subscribeToRoom(room.code);
      if (!_disposed && fresh.gameState != null) {
        room = fresh;
        _apply(fresh.gameState!);
      }
    } catch (_) {
      // Offline: keep showing the last known state; the next reconnect resyncs.
    }
  }

  // --- internals -----------------------------------------------------------

  void _apply(Map<String, dynamic> next) {
    if (_disposed) return;
    // Ignore stale or out-of-order states.
    if ((next['version'] as int) < version) return;
    state = next;
    busy = false;
    error = null;
    notifyListeners();
    _scheduleSkip();
  }

  /// Every client reports an expired turn; the server accepts only the first
  /// and only if its own clock agrees, so clock skew just causes a retry.
  void _scheduleSkip({bool retry = false}) {
    _skipTimer?.cancel();
    if (_disposed || isOver) return;
    final ms =
        (state['turnDeadline'] as num).toInt() -
        DateTime.now().millisecondsSinceEpoch;
    final delay = retry
        ? const Duration(seconds: 2)
        : Duration(milliseconds: ms.clamp(0, 60000)) + skipSlack;
    final seen = version;
    _skipTimer = Timer(delay, () async {
      try {
        await socket.skipTurn(room.code);
      } catch (_) {}
      if (!_disposed && version == seen) _scheduleSkip(retry: true);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _connSub?.cancel();
    _reactSub?.cancel();
    _skipTimer?.cancel();
    super.dispose();
  }
}
