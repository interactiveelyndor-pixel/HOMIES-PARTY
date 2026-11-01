import 'dart:async';

import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/party_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

Map<String, dynamic> party({int round = 1, bool finished = false, Map<String, int>? scores}) => {
  'rounds': 3,
  'round': round,
  'scores': scores ?? <String, int>{},
  'history': [],
  'finished': finished,
};

Map<String, dynamic> c4State() => {
  'players': [
    {'userId': 'me', 'color': 1},
    {'userId': 'you', 'color': 2},
  ],
  'board': List.generate(6, (_) => List.filled(7, 0)),
  'turn': 0,
  'winnerId': null,
  'draw': false,
  'version': 0,
  'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
  'lastMove': null,
  'winningCells': [],
};

Room room({String type = 'connect4', Map<String, dynamic>? p, Map<String, dynamic>? state}) =>
    Room.fromJson({
      'id': 'r',
      'code': 'ABC234',
      'hostUserId': 'me',
      'status': 'playing',
      'maxPlayers': 4,
      'gameType': type,
      'gameState': state ?? c4State(),
      'party': p ?? party(),
      'players': [
        {'userId': 'me', 'nickname': 'Me'},
        {'userId': 'you', 'nickname': 'Zed'},
      ],
    });

void main() {
  testWidgets('shows the round and scores, follows server updates and new rounds', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(() => t.view.resetPhysicalSize());
    final updates = StreamController<Room>.broadcast();
    final starts = StreamController<Room>.broadcast();
    addTearDown(updates.close);
    addTearDown(starts.close);

    await t.pumpWidget(MaterialApp(
      home: PartyScreen(
        room: room(),
        myUserId: 'me',
        roomUpdates: updates.stream,
        roomStarts: starts.stream,
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('🎉 Party · Round 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('c4_status')), findsOneWidget, reason: 'Connect Four is running');
    expect(find.byKey(const Key('party_score_me')), findsOneWidget);

    // A round ended elsewhere: scores update, the game is not rebuilt.
    updates.add(room(p: party(scores: {'me': 3, 'you': 1})));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: find.byKey(const Key('party_score_me')), matching: find.text('Me  3')), findsOneWidget);
    expect(find.byKey(const Key('c4_status')), findsOneWidget);

    // Next round: a different game replaces the screen.
    starts.add(room(type: 'snl', p: party(round: 2, scores: {'me': 3, 'you': 1}), state: {
      'players': [
        {'userId': 'me', 'position': 1},
        {'userId': 'you', 'position': 1},
      ],
      'turn': 0,
      'winnerId': null,
      'version': 5,
      'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
      'lastRoll': null,
      'lastEvent': null,
    }));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('🎉 Party · Round 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('c4_status')), findsNothing);
    expect(find.byKey(const Key('online_snl_roll')), findsOneWidget);

    // Updates for another room are ignored.
    updates.add(Room.fromJson({'id': 'x', 'code': 'OTHER9', 'party': party(round: 3)}));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('🎉 Party · Round 2 of 3'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the bar announces the winner when the party ends', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PartyBar(room: room(p: party(round: 3, finished: true, scores: {'me': 5, 'you': 8}))),
      ),
    ));
    expect(find.text('🏆 Zed wins the party!'), findsOneWidget);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PartyBar(room: room(p: party(round: 3, finished: true, scores: {'me': 6, 'you': 6}))),
      ),
    ));
    expect(find.textContaining('tie'), findsOneWidget);
  });

  test('the next-round button exists until the last round', () {
    String? label(Map<String, dynamic>? p) => OnlineGameSession(
      room: Room.fromJson({
        'id': 'r', 'code': 'ABC234', 'hostUserId': 'me', 'status': 'playing', 'maxPlayers': 2,
        'gameType': 'connect4', 'gameState': c4State(), 'party': ?p,
        'players': [],
      }),
      myUserId: 'me',
      socket: FakeSocket(),
    ).rematchLabel;
    expect(label(null), 'Rematch');
    expect(label(party(round: 1)), 'Next round');
    expect(label(party(round: 3)), isNull);
  });
}
