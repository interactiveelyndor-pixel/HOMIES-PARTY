import 'dart:async';
import 'package:classic_ludo/network/network.dart';

/// In-memory stand-in for the real-time connection, for tests.
class FakeSocket implements GameSocket {
  final stateCtl = StreamController<Map<String, dynamic>>.broadcast();
  final connCtl = StreamController<bool>.broadcast();
  final reactCtl = StreamController<Map<String, dynamic>>.broadcast();
  final calls = <String>[];
  final revisions = <int?>[]; // expectedRevision sent with each roll/move
  Room? subscribeResult;
  Object? actionError;
  Completer<void>? hold; // make an action wait

  @override
  Stream<Map<String, dynamic>> get onGameState => stateCtl.stream;
  @override
  Stream<bool> get onConnectionStateChanged => connCtl.stream;
  @override
  Stream<Map<String, dynamic>> get onReaction => reactCtl.stream;

  @override
  Future<Room> subscribeToRoom(String code) async {
    calls.add('subscribe:$code');
    final r = subscribeResult;
    if (r == null) throw const ApiException(statusCode: 503, error: 'x', message: 'offline');
    return r;
  }

  Future<void> _act(String name) async {
    calls.add(name);
    if (hold != null) await hold!.future;
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> rollDice(String code, {int? expectedRevision}) {
    revisions.add(expectedRevision);
    return _act('roll');
  }

  @override
  Future<void> move(String code, Map<String, dynamic> input, {int? expectedRevision}) {
    revisions.add(expectedRevision);
    return _act('move:${input['column'] ?? input['token']}');
  }
  @override
  Future<void> skipTurn(String code) => _act('skip');
  @override
  Future<void> rematch(String code) => _act('rematch');
  @override
  Future<void> react(String code, String emoji) => _act('react:$emoji');
}
