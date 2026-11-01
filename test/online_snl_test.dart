import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/online_snl_screen.dart';
import 'package:classic_ludo/ui/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _server({String? winner, int turn = 0}) => {
      'players': [
        {'userId': 'a', 'position': 12},
        {'userId': 'b', 'position': 100},
      ],
      'turn': turn,
      'lastRoll': 4,
      'winnerId': winner,
      'version': 3,
      'turnDeadline': 9999999999999,
    };

Room _room(Map<String, dynamic> gs) => Room.fromJson({
      'id': 'r',
      'code': 'ABC234',
      'hostUserId': 'a',
      'status': 'playing',
      'maxPlayers': 2,
      'gameState': gs,
      'players': [
        {'userId': 'a', 'nickname': 'Ann'},
        {'userId': 'b', 'nickname': 'Bob'},
      ],
    });

void main() {
  sizeTests();
  test('maps server state to SnlGameState', () {
    final s = snlStateFromServer(_room(_server()), _server());
    expect(s.players.map((p) => p.name), ['Ann', 'Bob']);
    expect(s.players[0].position, 12);
    expect(s.currentPlayerIndex, 0);
    expect(s.isGameOver, isFalse);
    final w =
        snlStateFromServer(_room(_server(winner: 'b')), _server(winner: 'b'));
    expect(w.isGameOver, isTrue);
    expect(w.winner!.name, 'Bob');
  });

  testWidgets('finished game offers a rematch button', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(MaterialApp(
      home: OnlineSnlScreen(
          room: _room(_server(winner: 'b')), myUserId: 'a'),
    ));
    final btn =
        tester.widget<AppButton>(find.byKey(const Key('online_snl_roll')));
    expect(btn.text, 'Rematch');
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('roll button only enabled on my turn', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    for (final me in ['a', 'b']) {
      await tester.pumpWidget(MaterialApp(
        home: OnlineSnlScreen(
            key: ValueKey(me), room: _room(_server()), myUserId: me),
      ));
      final btn =
          tester.widget<AppButton>(find.byKey(const Key('online_snl_roll')));
      expect(btn.onPressed != null, me == 'a');
      expect(tester.takeException(), isNull);
    }
  });
}

void sizeTests() {
  for (final size in [const Size(360, 640), const Size(412, 923)]) {
    testWidgets('online Snakes & Ladders fits ${size.width.toInt()}x${size.height.toInt()} at 1.4x text',
        (tester) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: OnlineSnlScreen(room: _room(_server()), myUserId: 'a'),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
