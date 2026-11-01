import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/online_connect4_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_game_socket.dart';

List<List<int>> emptyBoard() => List.generate(6, (_) => List.filled(7, 0));

Map<String, dynamic> c4State({
  List<List<int>>? board,
  int turn = 0,
  String? winner,
  bool draw = false,
  int version = 1,
  List<Map<String, int>> winning = const [],
  Map<String, int>? last,
}) =>
    {
      'players': [
        {'userId': 'me'},
        {'userId': 'you'},
      ],
      'turn': turn,
      'board': board ?? emptyBoard(),
      'lastMove': last,
      'winningCells': winning,
      'winnerId': winner,
      'draw': draw,
      'version': version,
      'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
    };

Room roomWith(Map<String, dynamic> state) => Room.fromJson({
      'id': 'r',
      'code': 'ABC234',
      'hostUserId': 'me',
      'status': 'playing',
      'maxPlayers': 2,
      'gameType': 'connect4',
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
    home: OnlineConnectFourScreen(
      key: UniqueKey(),
      room: roomWith(state),
      myUserId: me,
      socket: socket,
    ),
  ));
  await t.pumpAndSettle();
  return socket;
}

String status(WidgetTester t) => t
    .widget<Text>(find.descendant(
        of: find.byKey(const Key('c4_status')), matching: find.byType(Text)))
    .data!;

void main() {
  test('server state maps onto a drawable board', () {
    final board = emptyBoard()..[5][3] = 1;
    final g = connectFourFromServer(c4State(
      board: board,
      turn: 1,
      winner: 'you',
      winning: [
        {'row': 5, 'col': 3},
        {'row': 4, 'col': 3},
      ],
      last: {'row': 5, 'col': 3},
    ));
    expect(g.board[5][3], 1);
    expect(g.current, 2);
    expect(g.winner, 2, reason: 'second player = yellow');
    expect(g.winningCells, [(5, 3), (4, 3)]);
    expect(g.lastMove, (5, 3));
    expect(connectFourFromServer(c4State()).winner, 0);
  });

  testWidgets('draws the server board and says whose turn it is', (t) async {
    final board = emptyBoard()
      ..[5][3] = 1
      ..[5][4] = 2;
    await pump(t, c4State(board: board, turn: 0));
    expect(find.byKey(const Key('c4_disc_5_3')), findsOneWidget);
    expect(find.byKey(const Key('c4_disc_5_4')), findsOneWidget);
    expect(status(t), 'Your turn');
    expect(find.text('You are pink'), findsOneWidget);
  });

  testWidgets('the second player sees yellow and waits for the opponent',
      (t) async {
    await pump(t, c4State(turn: 0), me: 'you');
    expect(find.text('You are yellow'), findsOneWidget);
    expect(status(t), "Me's turn");
  });

  testWidgets('tapping a column sends the move only on your turn', (t) async {
    final mine = await pump(t, c4State(turn: 0));
    await t.tap(find.byKey(const Key('c4_column_3')));
    await t.pump();
    expect(mine.calls, contains('move:3'));

    final theirs = await pump(t, c4State(turn: 1));
    await t.tap(find.byKey(const Key('c4_column_3')));
    await t.pump();
    expect(theirs.calls.where((c) => c.startsWith('move')), isEmpty);
  });

  testWidgets('a pushed state updates the board and the turn', (t) async {
    final s = await pump(t, c4State(turn: 1));
    expect(status(t), "Zed's turn");
    final board = emptyBoard()..[5][0] = 2;
    s.stateCtl.add({
      'code': 'ABC234',
      'state': c4State(
          board: board, turn: 0, version: 2, last: {'row': 5, 'col': 0}),
    });
    await t.pumpAndSettle();
    expect(find.byKey(const Key('c4_disc_5_0')), findsOneWidget);
    expect(status(t), 'Your turn');
  });

  testWidgets('winning, losing and drawing are announced', (t) async {
    final win = {'row': 5, 'col': 0};
    await pump(t, c4State(winner: 'me', winning: [win]));
    expect(status(t), 'You win!');
    expect(find.byKey(const Key('c4_rematch')), findsOneWidget);

    await pump(t, c4State(winner: 'you', turn: 1, winning: [win]), me: 'me');
    expect(status(t), 'Zed wins!');

    await pump(t, c4State(draw: true));
    expect(status(t), "It's a draw");
  });

  testWidgets('rematch asks the server for a new game', (t) async {
    final s = await pump(t, c4State(winner: 'me'));
    await t.tap(find.byKey(const Key('c4_rematch')));
    await t.pump();
    expect(s.calls, contains('rematch'));
  });

  testWidgets('a server rejection is shown to the player', (t) async {
    final s = await pump(t, c4State());
    s.actionError = const ApiException(
        statusCode: 409, error: 'Conflict', message: 'That column is full.');
    await t.tap(find.byKey(const Key('c4_column_0')));
    await t.pumpAndSettle();
    expect(find.text('That column is full.'), findsOneWidget);
  });

  testWidgets('reaction buttons send, and reactions from others show with their name',
      (t) async {
    final s = await pump(t, c4State());
    await t.tap(find.byKey(const Key('react_🔥')));
    await t.pump();
    expect(s.calls, contains('react:🔥'));

    s.reactCtl.add({'code': 'ABC234', 'userId': 'you', 'emoji': '😂'});
    s.reactCtl.add({'code': 'ABC234', 'userId': 'me', 'emoji': '👏'});
    await t.pump();
    await t.pump();
    expect(find.text('Zed 😂'), findsOneWidget);
    expect(find.text('👏'), findsWidgets);
    await t.pump(const Duration(seconds: 4)); // let the feed expire
    expect(find.text('Zed 😂'), findsNothing);
  });

  for (final size in [const Size(360, 640), const Size(412, 923)]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} at 1.4x text',
        (t) async {
      t.view.physicalSize = Size(size.width * 2, size.height * 2);
      t.view.devicePixelRatio = 2.0;
      addTearDown(() => t.view.resetPhysicalSize());
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: OnlineConnectFourScreen(
          room: roomWith(c4State(winner: 'you', turn: 1)),
          myUserId: 'me',
          socket: FakeSocket(),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
