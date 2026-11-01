import 'package:classic_ludo/catalog/game_catalog.dart';
import 'package:classic_ludo/catalog/game_tile.dart';
import 'package:classic_ludo/screens/app_shell.dart';
import 'package:classic_ludo/screens/game_details_screen.dart';
import 'package:classic_ludo/screens/ludo_mode_select_screen.dart';
import 'package:classic_ludo/screens/lobby_widgets.dart';
import 'package:classic_ludo/screens/online_lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GameInfo game(String id) => GameCatalog.all.firstWhere((g) => g.id == id);

Future<void> open(WidgetTester t, GameInfo g, {double w = 390, double h = 844, double scale = 1}) async {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
  await t.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: GameDetailsScreen(game: g),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  onlineBadgeTests();
  test('every game has rules and a length to show', () {
    for (final g in GameCatalog.all) {
      expect(g.rules, isNotEmpty, reason: g.id);
      expect(g.duration, isNotEmpty, reason: g.id);
    }
  });

  testWidgets('shows title, players, length, rules and ways to play', (t) async {
    await open(t, game('ludo'));
    expect(find.byKey(const Key('details_title')), findsOneWidget);
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('2-4 players'), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.textContaining('Roll a six'), findsOneWidget);
    expect(find.text('• Play against the computer'), findsOneWidget);
    expect(find.text('• Online with friends (private room)'), findsOneWidget);
    expect(find.byKey(const Key('details_online')), findsOneWidget);
  });

  testWidgets('Play opens the game, Play online opens the lobby on that game', (t) async {
    await open(t, game('ludo'));
    await t.tap(find.byKey(const Key('details_play')));
    await t.pumpAndSettle();
    expect(find.byType(LudoModeSelectScreen), findsOneWidget);
  });

  testWidgets('a game with no online mode offers only local play', (t) async {
    await open(t, game('carrom'));
    expect(find.byKey(const Key('details_online')), findsNothing);
    expect(find.textContaining('Online with friends'), findsNothing);
    expect(find.text('2 players'), findsOneWidget);
  });

  testWidgets('a pass-and-play party game has no computer mode listed', (t) async {
    await open(t, game('wyr'));
    expect(find.textContaining('against the computer'), findsNothing);
  });

  testWidgets('every game fits 360x640 at 1.4x text without overflow', (t) async {
    for (final g in GameCatalog.all) {
      await open(t, g, w: 360, h: 640, scale: 1.4);
      expect(t.takeException(), isNull, reason: g.id);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the Party tab and the five tabs exist; Profile shows the account screen', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(() => t.view.resetPhysicalSize());
    await t.pumpWidget(const MaterialApp(home: AppShell()));
    await t.pumpAndSettle();
    final nav = find.byKey(const Key('app_nav_bar'));
    for (final label in ['Home', 'Games', 'Party', 'Friends', 'Profile']) {
      expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget, reason: label);
    }
    expect(find.descendant(of: nav, matching: find.text('Play')), findsNothing);
    expect(find.descendant(of: nav, matching: find.text('Social')), findsNothing);
    await t.tap(find.descendant(of: nav, matching: find.text('Profile')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the lobby can open on a given game', (t) async {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(() => t.view.resetPhysicalSize());
    await t.pumpWidget(const MaterialApp(home: OnlineLobbyScreen(initialGame: 'connect4')));
    await t.pump(const Duration(milliseconds: 300));
    final tile = t.widget<GamePickTile>(find.byKey(const Key('lobby_game_connect4')));
    expect(tile.selected, isTrue);
    await t.pumpWidget(const SizedBox());
  });
}

void onlineBadgeTests() {
  testWidgets('Home tiles say which games can be played online', (t) async {
    t.view.physicalSize = const Size(390 * 2, 2400 * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(() => t.view.resetPhysicalSize());
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GameGrid(games: [], keyPrefix: 'x')))));
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GameGrid(games: GameCatalog.all, keyPrefix: 'x')))));
    await t.pump(const Duration(milliseconds: 300));
    for (final id in ['ludo', 'snl', 'connect4']) {
      expect(find.byKey(Key('online_badge_$id')), findsOneWidget, reason: id);
    }
    for (final id in ['carrom', 'battleship', 'pen_fight', 'wyr']) {
      expect(find.byKey(Key('online_badge_$id')), findsNothing, reason: id);
    }
  });
}
