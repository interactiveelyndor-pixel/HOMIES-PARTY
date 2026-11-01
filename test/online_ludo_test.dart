import 'package:classic_ludo/models/game_state.dart';
import 'package:classic_ludo/models/player_color.dart';
import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/online_ludo_screen.dart';
import 'package:classic_ludo/widgets/dice_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

Map<String, dynamic> ludoState({
  int turn = 0,
  String phase = 'roll',
  int? dice,
  List<int> movable = const [],
  List<int>? redTokens,
  List<int>? yellowTokens,
  String? winner,
  String lastEvent = 'none',
  int? lastRoll,
  int lastActor = 0,
  int version = 1,
}) =>
    {
      'players': [
        {'userId': 'me', 'color': 0, 'tokens': redTokens ?? [-1, -1, -1, -1]},
        {'userId': 'you', 'color': 2, 'tokens': yellowTokens ?? [-1, -1, -1, -1]},
      ],
      'turn': turn,
      'phase': phase,
      'dice': dice,
      'movable': movable,
      'consecutiveSixes': 0,
      'lastRoll': lastRoll,
      'lastActor': lastActor,
      'lastEvent': lastEvent,
      'winnerId': winner,
      'draw': false,
      'version': version,
      'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
    };

Room roomWith(Map<String, dynamic> state) => Room.fromJson({
      'id': 'r',
      'code': 'LUD234',
      'hostUserId': 'me',
      'status': 'playing',
      'maxPlayers': 2,
      'gameType': 'ludo',
      'gameState': state,
      'players': [
        {'userId': 'me', 'nickname': 'Me'},
        {'userId': 'you', 'nickname': 'Zed'},
      ],
    });

Future<FakeSocket> pump(WidgetTester t, Map<String, dynamic> state,
    {String me = 'me', double w = 390, double h = 844}) async {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
  final socket = FakeSocket();
  await t.pumpWidget(MaterialApp(
    home: OnlineLudoScreen(
        key: UniqueKey(), room: roomWith(state), myUserId: me, socket: socket),
  ));
  // The dice and glowing tokens animate forever, so pumpAndSettle would never return.
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  return socket;
}

String status(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('online_ludo_status'))).data!;
String note(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('online_ludo_note'))).data!;
bool canRoll(WidgetTester t) =>
    t.widget<DiceWidget>(find.byKey(const Key('online_ludo_dice'))).canRoll;

void main() {
  group('state mapping', () {
    test('colours, steps, names and the dice come from the server', () {
      final g = ludoStateFromServer(
        roomWith(ludoState()),
        ludoState(
            redTokens: [-1, 5, 56, 20],
            yellowTokens: [0, -1, -1, -1],
            lastRoll: 4),
        'me',
      );
      expect(g.players.map((p) => p.color),
          [PlayerColor.red, PlayerColor.yellow]);
      expect(g.players.map((p) => p.name), ['Me', 'Zed']);
      expect(g.players[0].tokens.map((t) => t.stepCount), [-1, 5, 56, 20]);
      expect(g.players[0].tokens[2].isHome, isTrue);
      expect(g.diceValue, 4);
      expect(g.phase, TurnPhase.waitingForRoll);
    });

    test('tokens glow only for the viewer, and only while choosing', () {
      final s = ludoState(
          phase: 'move', dice: 3, movable: [0, 2], redTokens: [4, 9, 12, -1]);
      expect(ludoStateFromServer(roomWith(s), s, 'me').movableTokenIds, {0, 2});
      expect(ludoStateFromServer(roomWith(s), s, 'you').movableTokenIds,
          isEmpty);
      expect(ludoStateFromServer(roomWith(s), s, 'me').phase,
          TurnPhase.waitingForTokenSelection);
      expect(ludoStateFromServer(roomWith(s), s, 'me').diceValue, 3);
    });

    test('a winner ends the game', () {
      final s = ludoState(winner: 'you', turn: 1);
      final g = ludoStateFromServer(roomWith(s), s, 'me');
      expect(g.isGameOver, isTrue);
      expect(g.winner!.name, 'Zed');
    });
  });

  test('event text uses plain words and the right person', () {
    expect(ludoEventText('capture', 4, 'You'),
        'You captured a token. Roll again!');
    expect(ludoEventText('capture', 4, 'Zed'),
        'Zed captured a token. They roll again.');
    expect(ludoEventText('noMove', 3, 'Zed'), 'Zed rolled 3. No move possible.');
    expect(ludoEventText('forfeit', 6, 'You'),
        'You rolled three 6s in a row and lose the turn.');
    expect(ludoEventText('forfeit', 6, 'Zed'),
        'Zed rolled three 6s in a row and loses the turn.');
    expect(ludoEventText('none', 5, 'Zed'), 'Zed rolled 5.');
    expect(ludoEventText('six', 6, 'You'), 'You rolled a 6. Roll again!');
  });

  testWidgets('says what to do on your turn and whose turn it is otherwise',
      (t) async {
    await pump(t, ludoState());
    expect(status(t), 'Your turn: roll!');
    expect(find.text('You are red'), findsOneWidget);
    await pump(t, ludoState(turn: 1));
    expect(status(t), "Zed's turn");
    await pump(t, ludoState(phase: 'move', dice: 6, movable: [0, 1, 2, 3]));
    expect(status(t), 'Pick a token to move');
    await pump(t, ludoState(), me: 'you');
    expect(find.text('You are yellow'), findsOneWidget);
  });

  testWidgets('the dice can be rolled only on your own roll', (t) async {
    final mine = await pump(t, ludoState());
    expect(canRoll(t), isTrue);
    await t.tap(find.byKey(const Key('online_ludo_dice')));
    await t.pump();
    expect(mine.calls, contains('roll'));

    final theirs = await pump(t, ludoState(turn: 1));
    expect(canRoll(t), isFalse);
    await t.tap(find.byKey(const Key('online_ludo_dice')));
    await t.pump();
    expect(theirs.calls.where((c) => c == 'roll'), isEmpty);

    await pump(t, ludoState(phase: 'move', dice: 6, movable: [0, 1, 2, 3]));
    expect(canRoll(t), isFalse, reason: 'a token must be chosen first');
  });

  testWidgets('tapping a movable token of yours sends that token', (t) async {
    final s = await pump(
        t,
        ludoState(
            phase: 'move',
            dice: 3,
            movable: [1, 2],
            redTokens: [-1, 4, 9, -1]));
    await t.tap(find.byKey(ValueKey('token_${PlayerColor.red}_2')));
    await t.pump();
    expect(s.calls, contains('move:2'));
  });

  testWidgets('tokens that cannot move, or are not yours, send nothing',
      (t) async {
    final s = await pump(
        t,
        ludoState(
            phase: 'move',
            dice: 3,
            movable: [1],
            redTokens: [-1, 4, 9, -1],
            yellowTokens: [7, -1, -1, -1]));
    await t.tap(find.byKey(ValueKey('token_${PlayerColor.red}_2')),
        warnIfMissed: false);
    await t.tap(find.byKey(ValueKey('token_${PlayerColor.yellow}_0')),
        warnIfMissed: false);
    await t.pump();
    expect(s.calls.where((c) => c.startsWith('move')), isEmpty);

    final other = await pump(
        t,
        ludoState(
            turn: 1,
            phase: 'move',
            dice: 3,
            movable: [0],
            yellowTokens: [7, -1, -1, -1]));
    await t.tap(find.byKey(ValueKey('token_${PlayerColor.yellow}_0')),
        warnIfMissed: false);
    await t.pump();
    expect(other.calls.where((c) => c.startsWith('move')), isEmpty,
        reason: "it is the other player's choice");
  });

  testWidgets('shows what the last action did, by name', (t) async {
    await pump(
        t,
        ludoState(
            lastEvent: 'capture',
            lastRoll: 4,
            lastActor: 1,
            redTokens: [10, -1, -1, -1]));
    expect(note(t), 'Zed captured a token. They roll again.');
    await pump(
        t,
        ludoState(
            lastEvent: 'noMove', lastRoll: 2, lastActor: 0, turn: 1));
    expect(note(t), 'You rolled 2. No move possible.');
    await pump(t, ludoState());
    expect(note(t), '');
  });

  testWidgets('winning or losing is announced and a rematch can be asked for',
      (t) async {
    await pump(t, ludoState(winner: 'me'));
    expect(status(t), 'You win!');
    final s = await pump(t, ludoState(winner: 'you', turn: 1));
    expect(status(t), 'Zed wins!');
    await t.tap(find.byKey(const Key('online_ludo_rematch')));
    await t.pump();
    expect(s.calls, contains('rematch'));
  });

  testWidgets('a pushed state moves the game on, and reactions work',
      (t) async {
    final s = await pump(t, ludoState(turn: 1));
    expect(status(t), "Zed's turn");
    s.stateCtl.add({'code': 'LUD234', 'state': ludoState(turn: 0, version: 2)});
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(status(t), 'Your turn: roll!');
    await t.tap(find.byKey(const Key('react_🔥')));
    await t.pump();
    expect(s.calls, contains('react:🔥'));
  });

  for (final size in [const Size(360, 640), const Size(412, 923)]) {
    testWidgets(
        'fits ${size.width.toInt()}x${size.height.toInt()} at 1.4x text',
        (t) async {
      t.view.physicalSize = Size(size.width * 2, size.height * 2);
      t.view.devicePixelRatio = 2.0;
      addTearDown(() => t.view.resetPhysicalSize());
      for (final state in [
        ludoState(),
        ludoState(
            winner: 'you',
            turn: 1,
            lastEvent: 'capture',
            lastRoll: 5,
            lastActor: 1),
      ]) {
        await t.pumpWidget(MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: OnlineLudoScreen(
              key: UniqueKey(),
              room: roomWith(state),
              myUserId: 'me',
              socket: FakeSocket()),
        ));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
      }
    });
  }
}
