import 'package:classic_ludo/would_you_rather/wyr_game_screen.dart';
import 'package:classic_ludo/would_you_rather/wyr_logic.dart';
import 'package:classic_ludo/would_you_rather/wyr_prompts.dart';
import 'package:classic_ludo/would_you_rather/wyr_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _phone(WidgetTester t, {double w = 390, double h = 844}) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
}

WyrGame _game({int players = 2, int rounds = 1}) => WyrGame(
      players: [for (var i = 1; i <= players; i++) 'P$i'],
      prompts: wyrPrompts.take(rounds).toList(),
    );

String _text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets('setup: player count stays between 2 and 8', (t) async {
    _phone(t);
    await t.pumpWidget(const MaterialApp(home: WyrSetupScreen()));
    expect(_text(t, 'wyr_players'), '3');
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byKey(const Key('wyr_players_plus')));
      await t.pump();
    }
    expect(_text(t, 'wyr_players'), '8');
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byKey(const Key('wyr_players_minus')));
      await t.pump();
    }
    expect(_text(t, 'wyr_players'), '2');
  });

  testWidgets('setup starts a game with the chosen player count', (t) async {
    _phone(t);
    await t.pumpWidget(const MaterialApp(home: WyrSetupScreen()));
    await t.tap(find.byKey(const Key('wyr_start')));
    await t.pumpAndSettle();
    expect(t.widget<WyrGameScreen>(find.byType(WyrGameScreen)).playerCount, 3);
    expect(find.byKey(const Key('wyr_voter')), findsOneWidget);
  });

  testWidgets('the question stays hidden until the voter taps ready',
      (t) async {
    _phone(t);
    final g = _game();
    await t.pumpWidget(MaterialApp(home: WyrGameScreen(playerCount: 2, game: g)));
    expect(_text(t, 'wyr_voter'), 'P1');
    expect(find.text(wyrPrompts[0].a), findsNothing);
    expect(find.text(wyrPrompts[0].b), findsNothing);

    await t.tap(find.byKey(const Key('wyr_ready')));
    await t.pump();
    expect(find.text(wyrPrompts[0].a), findsOneWidget);
    await t.tap(find.byKey(const Key('wyr_option_a')));
    await t.pump();

    // Hidden again for the next player, who is named.
    expect(find.text(wyrPrompts[0].a), findsNothing);
    expect(_text(t, 'wyr_voter'), 'P2');
  });

  testWidgets('full game: votes, reveal, final scores, play again', (t) async {
    _phone(t);
    final g = _game(players: 3);
    await t.pumpWidget(MaterialApp(home: WyrGameScreen(playerCount: 3, game: g)));

    for (final opt in ['a', 'a', 'b']) {
      await t.tap(find.byKey(const Key('wyr_ready')));
      await t.pump();
      await t.tap(find.byKey(Key('wyr_option_$opt')));
      await t.pump();
    }
    expect(_text(t, 'wyr_result'), 'The room says...');
    expect(_text(t, 'wyr_count_0'), '2');
    expect(_text(t, 'wyr_count_1'), '1');
    expect(find.text('P1, P2'), findsOneWidget);

    await t.tap(find.byKey(const Key('wyr_next')));
    await t.pump();
    expect(_text(t, 'wyr_winner'), "It's a tie: P1 and P2");

    await t.tap(find.byKey(const Key('wyr_play_again')));
    await t.pump();
    expect(find.byKey(const Key('wyr_voter')), findsOneWidget);
    expect(_text(t, 'wyr_title'), 'Question 1 of ${WyrGame.defaultRounds}');
  });

  testWidgets('a tie round says so', (t) async {
    _phone(t);
    await t.pumpWidget(MaterialApp(
        home: WyrGameScreen(playerCount: 2, game: _game())));
    for (final opt in ['a', 'b']) {
      await t.tap(find.byKey(const Key('wyr_ready')));
      await t.pump();
      await t.tap(find.byKey(Key('wyr_option_$opt')));
      await t.pump();
    }
    expect(_text(t, 'wyr_result'), 'A tie! Nobody scores.');
  });

  for (final size in [const Size(360, 640), const Size(412, 923)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()} with 1.4x text',
        (t) async {
      _phone(t, w: size.width, h: size.height);
      // Use the longest prompt pair to stress the layout.
      final longest = wyrPrompts.reduce(
          (a, b) => (a.a.length + a.b.length) >= (b.a.length + b.b.length) ? a : b);
      final g = WyrGame(players: ['Player 1', 'Player 2'], prompts: [longest]);
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: WyrGameScreen(playerCount: 2, game: g),
      ));
      for (var i = 0; i < 2; i++) {
        await t.tap(find.byKey(const Key('wyr_ready')));
        await t.pump();
        expect(t.takeException(), isNull, reason: 'question screen');
        await t.tap(find.byKey(const Key('wyr_option_a')));
        await t.pump();
      }
      expect(t.takeException(), isNull, reason: 'reveal screen');
      await t.tap(find.byKey(const Key('wyr_next')));
      await t.pump();
      expect(t.takeException(), isNull, reason: 'scores screen');
    });
  }
}
