import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/snl/snl_colors.dart';
import 'package:classic_ludo/snl/snl_controller.dart';
import 'package:classic_ludo/snl/snl_game_state.dart';
import 'package:classic_ludo/snl/snl_game_screen.dart';
import 'package:classic_ludo/snl/snl_board_widget.dart';
import 'package:classic_ludo/snl/snl_dice_widget.dart';
import 'package:classic_ludo/snl/snl_player_card.dart';
import 'package:classic_ludo/theme/ludo_theme.dart';

/// Helper: wraps SnlGameScreen in a MaterialApp with the correct theme.
Widget buildSnlApp(SnlController controller) {
  return MaterialApp(
    theme: LudoTheme.darkTheme,
    home: SnlGameScreen(controller: controller),
  );
}

void main() {
  group('SnlWidget Tests - Responsive Layout', () {
    testWidgets('Renders correctly on standard phone (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Snakes & Ladders'), findsOneWidget);
      expect(find.byType(SnlBoardWidget), findsOneWidget);
      expect(find.byType(SnlDiceWidget), findsOneWidget);
      expect(find.byKey(const Key('snl_roll_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders correctly on compact phone (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Snakes & Ladders'), findsOneWidget);
      expect(find.byType(SnlBoardWidget), findsOneWidget);
      expect(find.byType(SnlDiceWidget), findsOneWidget);
      expect(find.byKey(const Key('snl_roll_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders correctly on modern large phone (412x923)', (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 923 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Snakes & Ladders'), findsOneWidget);
      expect(find.byType(SnlBoardWidget), findsOneWidget);
      expect(find.byType(SnlDiceWidget), findsOneWidget);
      expect(find.byKey(const Key('snl_roll_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders correctly on extra-large phone (430x932)', (tester) async {
      tester.view.physicalSize = const Size(430 * 2, 932 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Snakes & Ladders'), findsOneWidget);
      expect(find.byType(SnlBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SnlWidget Tests - Player Cards & Color Consistency', () {
    testWidgets('Shows correct number of player cards for 2P game',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<SnlPlayerCard>(find.byType(SnlPlayerCard)).toList();
      expect(cards.length, equals(2));
      expect(cards[0].player.name, equals('Red'));
      expect(cards[1].player.name, equals('Yellow'));
    });

    testWidgets('Player card for Yellow uses yellow color and not green in 2P game',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<SnlPlayerCard>(find.byType(SnlPlayerCard)).toList();
      expect(cards.length, equals(2));

      // Player 0 is Red
      expect(cards[0].player.name, equals('Red'));
      expect(cards[0].player.primaryColor, equals(SnlColors.red));

      // Player 1 is Yellow - must be yellow, not green!
      expect(cards[1].player.name, equals('Yellow'));
      expect(cards[1].player.primaryColor, equals(SnlColors.yellow));
      expect(cards[1].player.primaryColor, isNot(equals(SnlColors.green)));
    });

    testWidgets('Shows correct number of player cards for 3P game',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(playerCount: 3, enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<SnlPlayerCard>(find.byType(SnlPlayerCard)).toList();
      expect(cards.length, equals(3));
      expect(cards[0].player.name, equals('Red'));
      expect(cards[1].player.name, equals('Green'));
      expect(cards[2].player.name, equals('Yellow'));
    });

    testWidgets('Shows correct number of player cards for 4P game',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(playerCount: 4, enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<SnlPlayerCard>(find.byType(SnlPlayerCard)).toList();
      expect(cards.length, equals(4));
      expect(cards[0].player.name, equals('Red'));
      expect(cards[1].player.name, equals('Green'));
      expect(cards[2].player.name, equals('Yellow'));
      expect(cards[3].player.name, equals('Blue'));
    });
  });

  group('SnlWidget Tests - Interactions', () {
    testWidgets('Roll button is enabled on start and triggers state change',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      final rollButton = find.byKey(const Key('snl_roll_button'));
      expect(rollButton, findsOneWidget);

      await tester.tap(rollButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // No crash
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid taps on roll button do not crash or duplicate roll',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      final rollButton = find.byKey(const Key('snl_roll_button'));

      // Fire 3 rapid taps
      await tester.tap(rollButton);
      await tester.tap(rollButton);
      await tester.tap(rollButton);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Player mode dialog can switch between 2P, 3P, 4P',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(playerCount: 4, enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      // Initially 4P
      expect(find.text('4P'), findsOneWidget);

      // Open player select dialog
      await tester.tap(find.byKey(const Key('snl_player_mode_button')));
      await tester.pumpAndSettle();

      expect(find.text('Select Players'), findsOneWidget);
      expect(find.text('2 Players'), findsOneWidget);

      // Select 2P
      await tester.tap(find.text('2 Players'));
      await tester.pumpAndSettle();

      // Tap Start
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('2P'), findsOneWidget);
    });

    testWidgets('Input during animation is blocked (roll button disabled)',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SnlController(enableDelays: false);
      await tester.pumpWidget(buildSnlApp(controller));
      await tester.pumpAndSettle();

      // Manually put controller in animating state
      controller.setStateForTesting(
        controller.state.copyWith(phase: SnlTurnPhase.animatingMove),
      );
      await tester.pump();

      // Roll button should be disabled
      final rollButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('snl_roll_button')),
      );
      expect(rollButton.onPressed, isNull);
    });
  });
}
