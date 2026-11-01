import 'dart:async';
import 'package:classic_ludo/network/network.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

Map<String, dynamic> gs({
  int version = 0,
  int turn = 0,
  String? winner,
  bool draw = false,
  int? deadline,
}) =>
    {
      'players': [
        {'userId': 'me'},
        {'userId': 'you'},
      ],
      'turn': turn,
      'winnerId': winner,
      'draw': draw,
      'version': version,
      'turnDeadline': deadline ?? DateTime.now().millisecondsSinceEpoch + 600000,
    };

Room room(Map<String, dynamic> state, {String code = 'ABC234'}) => Room.fromJson({
      'id': 'r',
      'code': code,
      'hostUserId': 'me',
      'status': 'playing',
      'maxPlayers': 2,
      'gameType': 'connect4',
      'gameState': state,
      'players': [
        {'userId': 'me', 'nickname': 'Me'},
        {'userId': 'you', 'nickname': 'You'},
      ],
    });

OnlineGameSession make(FakeSocket s, Map<String, dynamic> state,
        {Duration slack = const Duration(milliseconds: 10),
        Duration reactionLife = const Duration(seconds: 3)}) =>
    OnlineGameSession(
        room: room(state),
        myUserId: 'me',
        socket: s,
        skipSlack: slack,
        reactionLife: reactionLife);

Future<void> settle([int ms = 30]) => Future.delayed(Duration(milliseconds: ms));

void main() {
  test('reads the starting state and resyncs from the server on open', () async {
    final s = FakeSocket()..subscribeResult = room(gs(version: 5, turn: 1));
    final g = make(s, gs());
    expect(g.myTurn, isTrue);
    await settle();
    expect(s.calls, contains('subscribe:ABC234'));
    expect(g.version, 5);
    expect(g.myTurn, isFalse, reason: 'fresh state says it is the opponent\'s turn');
    g.dispose();
  });

  test('stale and foreign updates are ignored, newer ones applied', () async {
    final s = FakeSocket();
    final g = make(s, gs(version: 3));
    var notified = 0;
    g.addListener(() => notified++);

    s.stateCtl.add({'code': 'ABC234', 'state': gs(version: 2, turn: 1)});
    s.stateCtl.add({'code': 'OTHER9', 'state': gs(version: 9, turn: 1)});
    await settle();
    expect(g.version, 3);
    expect(notified, 0);

    s.stateCtl.add({'code': 'ABC234', 'state': gs(version: 4, turn: 1)});
    await settle();
    expect(g.version, 4);
    expect(g.myTurn, isFalse);
    expect(notified, 1);
    g.dispose();
  });

  test('act: needs your turn; no input rolls, an input moves', () async {
    final s = FakeSocket();
    final g = make(s, gs(turn: 1));
    await g.act({'column': 2});
    expect(s.calls.where((c) => c.startsWith('move') || c == 'roll'), isEmpty,
        reason: 'not my turn');

    s.stateCtl.add({'code': 'ABC234', 'state': gs(version: 1, turn: 0)});
    await settle();
    await g.act({'column': 2});
    expect(s.calls, contains('move:2'));

    s.stateCtl.add({'code': 'ABC234', 'state': gs(version: 2, turn: 0)});
    await settle();
    await g.act();
    expect(s.calls, contains('roll'));
    g.dispose();
  });

  test('a second tap while one is in flight is ignored', () async {
    final s = FakeSocket()..hold = Completer<void>();
    final g = make(s, gs());
    final first = g.act({'column': 1});
    await g.act({'column': 1}); // ignored: busy
    expect(s.calls.where((c) => c == 'move:1').length, 1);
    expect(g.busy, isTrue);
    s.hold!.complete();
    await first;
    expect(g.busy, isFalse);
    g.dispose();
  });

  test('server rejections surface as an error and clear busy', () async {
    final s = FakeSocket()
      ..actionError = const ApiException(statusCode: 409, error: 'Conflict', message: 'That column is full.');
    final g = make(s, gs());
    await g.act({'column': 0});
    expect(g.error, 'That column is full.');
    expect(g.busy, isFalse);
    // a fresh state clears the message
    s.stateCtl.add({'code': 'ABC234', 'state': gs(version: 1)});
    await settle();
    expect(g.error, isNull);
    g.dispose();
  });

  test('an expired turn is reported, a finished game never is', () async {
    final past = DateTime.now().millisecondsSinceEpoch - 1000;
    final s = FakeSocket();
    final g = make(s, gs(deadline: past));
    await settle(60);
    expect(s.calls, contains('skip'));
    g.dispose();

    final s2 = FakeSocket();
    final over = make(s2, gs(deadline: past, winner: 'you'));
    await settle(60);
    expect(s2.calls.where((c) => c == 'skip'), isEmpty);
    expect(over.isOver, isTrue);
    over.dispose();

    final s3 = FakeSocket();
    final tie = make(s3, gs(deadline: past, draw: true));
    await settle(60);
    expect(s3.calls.where((c) => c == 'skip'), isEmpty);
    expect(tie.isDraw && tie.isOver, isTrue);
    tie.dispose();
  });

  test('reconnecting re-subscribes and resyncs', () async {
    final s = FakeSocket();
    final g = make(s, gs());
    await settle();
    final before = s.calls.where((c) => c.startsWith('subscribe')).length;
    s.subscribeResult = room(gs(version: 7));
    s.connCtl.add(false);
    s.connCtl.add(true);
    await settle();
    expect(s.calls.where((c) => c.startsWith('subscribe')).length, before + 1);
    expect(g.version, 7);
    g.dispose();
  });

  test('rematch is forwarded and its rejection is shown', () async {
    final s = FakeSocket();
    final g = make(s, gs(winner: 'me'));
    await g.rematch();
    expect(s.calls, contains('rematch'));
    s.actionError = const ApiException(statusCode: 409, error: 'Conflict', message: 'Not yet.');
    await g.rematch();
    expect(g.error, 'Not yet.');
    g.dispose();
  });

  test('reactions for this room are collected, capped and expire', () async {
    final s = FakeSocket();
    final g = make(s, gs(), reactionLife: const Duration(milliseconds: 60));
    s.reactCtl.add({'code': 'OTHER9', 'userId': 'you', 'emoji': '🔥'});
    s.reactCtl.add({'code': 'ABC234', 'userId': 'you'}); // no emoji
    s.reactCtl.add({'code': 'ABC234', 'emoji': '🔥'}); // no sender
    await settle();
    expect(g.reactions, isEmpty);

    for (final e in ['👍', '😂', '😮', '🔥', '👏']) {
      s.reactCtl.add({'code': 'ABC234', 'userId': 'you', 'emoji': e});
    }
    await settle(10);
    expect(g.reactions.map((r) => r.emoji), ['😂', '😮', '🔥', '👏'], reason: 'oldest dropped at 4');
    await settle(120);
    expect(g.reactions, isEmpty, reason: 'each reaction disappears');
    g.dispose();
  });

  test('react sends once, ignores rapid repeats and swallows failures', () async {
    final s = FakeSocket();
    final g = make(s, gs());
    await g.react('🔥');
    await g.react('🔥'); // too soon
    expect(s.calls.where((c) => c == 'react:🔥').length, 1);
    await settle(560);
    s.actionError = const ApiException(statusCode: 429, error: 'x', message: 'Slow down');
    await g.react('👏'); // must not throw
    expect(s.calls, contains('react:👏'));
    expect(g.error, isNull, reason: 'a lost reaction does not interrupt the game');
    g.dispose();
  });

  test('after dispose nothing fires and nothing throws', () async {
    final past = DateTime.now().millisecondsSinceEpoch - 1000;
    final s = FakeSocket();
    final g = make(s, gs(deadline: past), slack: const Duration(milliseconds: 50));
    g.dispose();
    s.stateCtl.add({'code': 'ABC234', 'state': gs(version: 3)});
    await settle(120);
    expect(s.calls.where((c) => c == 'skip'), isEmpty);
  });
}
