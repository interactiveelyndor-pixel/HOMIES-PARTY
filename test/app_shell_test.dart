import 'package:classic_ludo/screens/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell tabs show all games and honest play options',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);

    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('games_ludo_card')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('games_wyr_card')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('games_wyr_card')), findsOneWidget);
    expect(find.byKey(const Key('games_connect4_card')), findsOneWidget);

    await tester.tap(find.descendant(of: find.byKey(const Key('app_nav_bar')), matching: find.text('Party')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('play_rooms')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
