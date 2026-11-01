import 'dart:math';
import 'package:classic_ludo/connect4/connect4_game_screen.dart';
import 'package:classic_ludo/connect4/connect4_logic.dart';
import 'package:classic_ludo/connect4/connect4_mode_select_screen.dart';
import 'package:classic_ludo/ui/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder get _discs => find.byWidgetPredicate(
    (w) => w.key.toString().contains('c4_disc_'));

String _status(WidgetTester t) =>
    t.widget<Text>(find.descendant(
        of: find.byKey(const Key('c4_status')), matching: find.byType(Text))).data!;

void _phone(WidgetTester t, {double w = 390, double h = 844}) {
  t.view.physicalSize = Size(w * 2, h * 2);
  t.view.devicePixelRatio = 2.0;
  addTearDown(() => t.view.resetPhysicalSize());
}

Future<void> _tapCol(WidgetTester t, int c) async {
  await t.tap(find.byKey(Key('c4_column_$c')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('mode select opens both modes', (t) async {
    _phone(t);
    await t.pumpWidget(const MaterialApp(home: ConnectFourModeSelectScreen()));
    await t.tap(find.byKey(const Key('c4_mode_friend')));
    await t.pumpAndSettle();
    expect(find.byType(ConnectFourGameScreen), findsOneWidget);
    expect(t.widget<ConnectFourGameScreen>(find.byType(ConnectFourGameScreen)).vsComputer,
        isFalse);
    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('c4_mode_computer')));
    await t.pumpAndSettle();
    expect(t.widget<ConnectFourGameScreen>(find.byType(ConnectFourGameScreen)).vsComputer,
        isTrue);
  });

  testWidgets('two players alternate and discs stack', (t) async {
    _phone(t);
    await t.pumpWidget(const MaterialApp(home: ConnectFourGameScreen()));
    expect(_status(t), "Pink's turn");
    await _tapCol(t, 3);
    expect(find.byKey(const Key('c4_disc_5_3')), findsOneWidget);
    expect(_status(t), "Yellow's turn");
    await _tapCol(t, 3);
    expect(find.byKey(const Key('c4_disc_4_3')), findsOneWidget);
    expect(_discs, findsNWidgets(2));
  });

  testWidgets('a win is announced and Play again clears the board', (t) async {
    _phone(t);
    await t.pumpWidget(const MaterialApp(home: ConnectFourGameScreen()));
    for (final c in [0, 0, 1, 1, 2, 2, 3]) {
      await _tapCol(t, c);
    }
    expect(_status(t), 'Pink wins!');
    final before = _discs.evaluate().length;
    await _tapCol(t, 4); // ignored: game over
    expect(_discs.evaluate().length, before);

    await t.tap(find.byKey(const Key('c4_play_again')));
    await t.pumpAndSettle();
    expect(_discs, findsNothing);
    expect(_status(t), "Pink's turn");
  });

  testWidgets('vs computer: it answers, and taps are ignored while it thinks',
      (t) async {
    _phone(t);
    await t.pumpWidget(MaterialApp(
      home: ConnectFourGameScreen(
        vsComputer: true,
        computerDelay: const Duration(milliseconds: 500),
        ai: ConnectFourAi(Random(1)),
      ),
    ));
    expect(_status(t), 'Your turn');
    await t.tap(find.byKey(const Key('c4_column_3')));
    await t.pump(const Duration(milliseconds: 100));
    expect(_status(t), 'Computer is thinking...');

    await t.tap(find.byKey(const Key('c4_column_0'))); // locked
    await t.pump(const Duration(milliseconds: 50));
    expect(_discs, findsNWidgets(1));

    await t.pumpAndSettle();
    expect(_discs, findsNWidgets(2));
    expect(_status(t), 'Your turn');
  });

  testWidgets('leaving mid-thought cancels the computer timer', (t) async {
    _phone(t);
    await t.pumpWidget(MaterialApp(
      home: ConnectFourGameScreen(
        vsComputer: true,
        computerDelay: const Duration(seconds: 5),
      ),
    ));
    await t.tap(find.byKey(const Key('c4_column_3')));
    await t.pump();
    await t.pumpWidget(const MaterialApp(home: SizedBox())); // dispose
    await t.pump(const Duration(seconds: 6)); // would throw if the timer ran
    expect(t.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(412, 923)]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} at 1.4x text',
        (t) async {
      _phone(t, w: size.width, h: size.height);
      await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: const ConnectFourGameScreen(),
      ));
      await _tapCol(t, 6);
      expect(t.takeException(), isNull);
    });
  }
}
