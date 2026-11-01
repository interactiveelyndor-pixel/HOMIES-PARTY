import 'dart:async';
import 'package:classic_ludo/network/network.dart';
import 'package:classic_ludo/screens/app_shell.dart';
import 'package:classic_ludo/screens/online_connect4_screen.dart';
import 'package:classic_ludo/screens/online_game_router.dart';
import 'package:classic_ludo/screens/quick_match_screen.dart';
import 'package:classic_ludo/ui/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMatcher implements MatchSocket {
  final searches = <Completer<Room>>[];
  final games = <String>[];
  int cancels = 0;

  @override
  MatchSearch findMatch(String gameType) {
    final c = Completer<Room>();
    searches.add(c);
    games.add(gameType);
    return MatchSearch(c.future, () {
      cancels++;
      if (!c.isCompleted) c.completeError(const MatchCancelled());
    });
  }
}

final me = UserProfile(id: 'me', nickname: 'Me', createdAt: DateTime(2026));

Room startedRoom({String gameType = 'connect4'}) => Room.fromJson({
      'id': 'r',
      'code': 'QQQ222',
      'hostUserId': 'me',
      'status': 'playing',
      'maxPlayers': 2,
      'gameType': gameType,
      'gameState': {
        'players': [
          {'userId': 'me'},
          {'userId': 'you'},
        ],
        'turn': 0,
        'board': List.generate(6, (_) => List.filled(7, 0)),
        'lastMove': null,
        'winningCells': [],
        'winnerId': null,
        'draw': false,
        'version': 0,
        'turnDeadline': DateTime.now().millisecondsSinceEpoch + 600000,
      },
      'players': [
        {'userId': 'me', 'nickname': 'Me'},
        {'userId': 'you', 'nickname': 'Zed'},
      ],
    });

Future<FakeMatcher> open(WidgetTester t,
    {Future<UserProfile> Function()? connect, String game = 'connect4'}) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
  final matcher = FakeMatcher();
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => QuickMatchScreen(
                game: onlineGames.firstWhere((g) => g.id == game),
                connect: connect ?? () async => me,
                matcher: matcher,
              ),
            )),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.byKey(const Key('open')));
  await t.pump();
  await t.pump();
  return matcher;
}

String status(WidgetTester t) => t.widget<Text>(find.byKey(const Key('qm_status'))).data!;

Future<void> leave(WidgetTester t) async {
  await t.pumpWidget(const MaterialApp(home: SizedBox()));
  await t.pump();
}

void main() {
  testWidgets('searches for the chosen game and counts the time', (t) async {
    final m = await open(t, game: 'snl');
    expect(m.games, ['snl']);
    expect(status(t), 'Looking for a player...');
    await t.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);
    await leave(t);
  });

  testWidgets('a match opens the game and stops the search timer', (t) async {
    final m = await open(t);
    m.searches.single.complete(startedRoom());
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(OnlineConnectFourScreen), findsOneWidget);
    expect(find.byType(QuickMatchScreen), findsNothing);
    expect(m.cancels, 0, reason: 'a finished search is not cancelled');
    await leave(t);
  });

  testWidgets('Cancel leaves the screen and cancels the server search',
      (t) async {
    final m = await open(t);
    await t.tap(find.byKey(const Key('qm_cancel')));
    await t.pumpAndSettle();
    expect(find.byType(QuickMatchScreen), findsNothing);
    expect(m.cancels, 1);
  });

  testWidgets('leaving by the back button also cancels', (t) async {
    final m = await open(t);
    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();
    expect(m.cancels, 1);
  });

  testWidgets('a timeout is explained and Search again starts a new search',
      (t) async {
    final m = await open(t);
    m.searches.last.completeError(const ApiException(
        statusCode: 408,
        error: 'Timeout',
        message: 'No one else is searching for this game right now.'));
    await t.pump();
    await t.pump();
    expect(status(t), 'No one else is searching for this game right now.');
    expect(find.byKey(const Key('qm_cancel')), findsNothing);

    await t.tap(find.byKey(const Key('qm_retry')));
    await t.pump();
    await t.pump();
    expect(m.searches.length, 2);
    expect(status(t), 'Looking for a player...');
    await leave(t);
  });

  testWidgets('a connection failure is shown and can be retried', (t) async {
    var attempts = 0;
    final m = await open(t, connect: () async {
      attempts++;
      if (attempts == 1) {
        throw const ApiException(
            statusCode: 503, error: 'NotConnected', message: 'Server unreachable.');
      }
      return me;
    });
    expect(status(t), 'Server unreachable.');
    expect(m.searches, isEmpty, reason: 'never searched while offline');
    await t.tap(find.byKey(const Key('qm_retry')));
    await t.pump();
    await t.pump();
    expect(m.searches.length, 1);
    expect(status(t), 'Looking for a player...');
    await leave(t);
  });

  testWidgets('a game this app cannot open is reported, not crashed on',
      (t) async {
    final m = await open(t);
    m.searches.single.complete(startedRoom(gameType: 'chess'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('update'), findsOneWidget);
    await leave(t);
  });

  testWidgets('Play tab: Quick match lists the online games', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(() => t.view.resetPhysicalSize());
    await t.pumpWidget(const MaterialApp(home: AppShell()));
    await t.tap(find.descendant(of: find.byKey(const Key('app_nav_bar')), matching: find.text('Party')));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -500)); // the tile is below the party card
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('play_match')));
    await t.pumpAndSettle();
    for (final g in onlineGames.where((g) => !g.privateOnly)) {
      expect(find.byKey(Key('qm_pick_${g.id}')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('qm_pick_bluff')),
      findsNothing,
      reason: 'games where players write text are private-room only',
    );
    await t.tap(find.byKey(const Key('qm_pick_connect4')));
    await t.pumpAndSettle();
    expect(find.byType(QuickMatchScreen), findsOneWidget);
    await leave(t);
  });
}
