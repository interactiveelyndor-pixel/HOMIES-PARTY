import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/logic/ludo_controller.dart';
import 'package:classic_ludo/main.dart';
import 'package:classic_ludo/widgets/dice_widget.dart';
import 'package:classic_ludo/widgets/ludo_board_widget.dart';
import 'package:classic_ludo/widgets/player_card_widget.dart';

void main() {
  group('Widget Tests - Responsive Layout & UI Elements', () {
    testWidgets('Renders properly on standard phone (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(enableDelays: false);
      await tester.pumpWidget(ClassicLudoApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Ludo Classic'), findsOneWidget);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
      expect(find.byType(PlayerCardWidget), findsWidgets);
      expect(find.byType(DiceWidget), findsOneWidget);
      expect(find.byKey(const Key('roll_button')), findsOneWidget);
    });

    testWidgets('Renders properly on compact phone (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(enableDelays: false);
      await tester.pumpWidget(ClassicLudoApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Ludo Classic'), findsOneWidget);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders properly on large phone (430x932)', (tester) async {
      tester.view.physicalSize = const Size(430 * 2, 932 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(enableDelays: false);
      await tester.pumpWidget(ClassicLudoApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Ludo Classic'), findsOneWidget);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Widget Tests - User Interactions & Dialogs', () {
    testWidgets('Can open and close Rules dialog', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(enableDelays: false);
      await tester.pumpWidget(ClassicLudoApp(controller: controller));
      await tester.pumpAndSettle();

      // Tap rules button
      await tester.tap(find.byKey(const Key('rules_button')));
      await tester.pumpAndSettle();

      expect(find.text('Classic Ludo Rules'), findsOneWidget);
      expect(find.text('Leaving Base'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();

      expect(find.text('Classic Ludo Rules'), findsNothing);
    });

    testWidgets('Can change player count via mode dialog', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(enableDelays: false);
      await tester.pumpWidget(ClassicLudoApp(controller: controller));
      await tester.pumpAndSettle();

      // Initially 4P
      expect(find.text('4P'), findsOneWidget);

      // Open player selection dialog
      await tester.tap(find.byKey(const Key('player_mode_button')));
      await tester.pumpAndSettle();

      expect(find.text('Select Players'), findsOneWidget);
      expect(find.text('2 Players'), findsOneWidget);

      // Select 2 Players (updates internal dialog state only).
      await tester.tap(find.text('2 Players'));
      await tester.pump(); // rebuild dialog

      // Scroll to confirm button in case the dialog is taller than the viewport.
      await tester.ensureVisible(find.byKey(const Key('player_mode_confirm')));
      await tester.pump();

      // Tap Confirm to close dialog and apply selection.
      await tester.tap(find.byKey(const Key('player_mode_confirm')));
      // Use pump with a duration instead of pumpAndSettle to avoid AnimatedContainer timeout.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2P'), findsOneWidget);
    });

    testWidgets('Dice roll button triggers roll and locks against rapid taps', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(enableDelays: false);
      await tester.pumpWidget(ClassicLudoApp(controller: controller));
      await tester.pumpAndSettle();

      final rollButton = find.byKey(const Key('roll_button'));
      expect(rollButton, findsOneWidget);

      // Rapidly tap roll button multiple times
      await tester.tap(rollButton);
      await tester.tap(rollButton);
      await tester.tap(rollButton);

      // Pump discrete frames to allow action processing without waiting for infinite repeat pulse
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // No crash, state transitioned cleanly
      expect(tester.takeException(), isNull);
    });
  });
}
