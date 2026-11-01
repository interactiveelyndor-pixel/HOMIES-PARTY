import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/ui/app_back_button.dart';
import 'package:classic_ludo/carrom/carrom_board_widget.dart';
import 'package:classic_ludo/carrom/carrom_controller.dart';
import 'package:classic_ludo/carrom/carrom_game_screen.dart';
import 'package:classic_ludo/carrom/carrom_mode_select_screen.dart';
import 'package:classic_ludo/carrom/carrom_models.dart';
import 'package:classic_ludo/carrom/carrom_player_card.dart';
import 'package:classic_ludo/screens/home_screen.dart';
import 'package:classic_ludo/theme/ludo_theme.dart';

Widget buildCarromTestApp(CarromController controller) {
  return MaterialApp(
    theme: LudoTheme.darkTheme,
    home: CarromGameScreen(controller: controller),
  );
}

void main() {
  group('CarromWidget Tests - Responsive Layout & Viewports', () {
    testWidgets('Renders cleanly on standard phone (390×844) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Classic Carrom'), findsOneWidget);
      expect(find.byType(CarromBoardWidget), findsOneWidget);
      expect(find.byType(CarromPlayerCard), findsNWidgets(2));
      expect(find.byKey(const Key('carrom_striker_slider')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on compact phone (360×640) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Classic Carrom'), findsOneWidget);
      expect(find.byType(CarromBoardWidget), findsOneWidget);
      expect(find.byType(CarromPlayerCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on modern tall phone (412×923) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 923 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Classic Carrom'), findsOneWidget);
      expect(find.byType(CarromBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on extra-large phone (430×932) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(430 * 2, 932 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Classic Carrom'), findsOneWidget);
      expect(find.byType(CarromBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CarromWidget Tests - UI Elements, Controls & Dialogs', () {
    testWidgets('Shows Player 1 (White) and Player 2 (Black) cards with initial score',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('(White)'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('(Black)'), findsOneWidget);
      expect(find.text('Score: 0 pts'), findsNWidgets(2));
      expect(find.text('(0 coins)'), findsNWidgets(2));
    });

    testWidgets('Can open and close Carrom rules dialog cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      // Tap rules button
      await tester.tap(find.byKey(const Key('carrom_rules_button')));
      await tester.pumpAndSettle();

      expect(find.text('Carrom Rules'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Carrom Rules'), findsNothing);
    });

    testWidgets('Can open and interact with reset dialog', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('carrom_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text('Restart Match?'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Restart Match?'), findsNothing);
    });

    testWidgets('Striker slider updates striker position', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      final slider = find.byKey(const Key('carrom_striker_slider'));
      expect(slider, findsOneWidget);

      // Drag slider
      await tester.drag(slider, const Offset(60, 0));
      await tester.pump();

      expect(controller.state.strikerX, greaterThan(400.0));
    });

    testWidgets('Input is locked when controller is in simulating phase',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      // Put controller in simulating phase
      controller.setStateForTesting(
        controller.state.copyWith(phase: CarromTurnPhase.simulating),
      );
      await tester.pump();

      final sliderWidget = tester.widget<Slider>(
        find.byKey(const Key('carrom_striker_slider')),
      );
      expect(sliderWidget.onChanged, isNull); // Disabled!
    });
  });

  group('Carrom - Home Screen Navigation', () {
    testWidgets(
        // CHANGED (reason): Carrom card now opens CarromModeSelectScreen first;
        // the test must tap "2 Players" to reach CarromGameScreen.
        'Home screen displays Carrom option card and navigates through mode select to CarromGameScreen',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 3 home cards exist.
      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      expect(find.byKey(const Key('home_snl_card')), findsOneWidget);
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);

      // Tap Carrom card → opens CarromModeSelectScreen.
      await tester.ensureVisible(find.byKey(const Key('home_carrom_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_carrom_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details_play')));
      await tester.pumpAndSettle();

      // Mode-select screen is visible with both options.
      expect(find.byType(CarromModeSelectScreen), findsOneWidget);
      expect(find.byKey(const Key('carrom_mode_2players')), findsOneWidget);
      expect(find.byKey(const Key('carrom_mode_vs_computer')), findsOneWidget);

      // Tap "2 Players" → opens CarromGameScreen (unchanged game).
      await tester.tap(find.byKey(const Key('carrom_mode_2players')));
      await tester.pumpAndSettle();

      expect(find.text('Classic Carrom'), findsOneWidget);
      expect(find.byType(CarromBoardWidget), findsOneWidget);
    });

    testWidgets('Mode select back button returns to home screen', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('home_carrom_card')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_carrom_card')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('details_play')));

      await tester.pumpAndSettle();

      expect(find.byType(CarromModeSelectScreen), findsOneWidget);

      // Tap back → returns to home.
      await tester.tap(find.byKey(const Key('carrom_mode_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CarromModeSelectScreen), findsNothing);
      // Back from the mode screen lands on Game Details; back again for the list.
      expect(find.byKey(const Key('details_title')), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);
    });

    testWidgets(
        'vs Computer mode: player 2 card shows CPU label and board initialises',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Launch CarromGameScreen directly in vs-computer mode.
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const CarromGameScreen(vsComputer: true),
        ),
      );
      await tester.pumpAndSettle();

      // Board and player cards are present.
      expect(find.byType(CarromBoardWidget), findsOneWidget);
      expect(find.byType(CarromPlayerCard), findsNWidgets(2));

      // Player 2 name is 'CPU'.
      expect(find.text('CPU'), findsOneWidget);

      // Player 1 is still named 'Player 1'.
      expect(find.text('Player 1'), findsOneWidget);
    });

    testWidgets(
        '2 Players mode: player names are unchanged (Player 1 / Player 2)',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController();
      await tester.pumpWidget(buildCarromTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
    });

    testWidgets(
        'Human input is blocked on board when it is the CPU turn (vsComputer mode)',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = CarromController(player2Name: 'CPU');
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: CarromGameScreen(
            vsComputer: true,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Force the state to be Player 2's turn (CPU) in positioning phase.
      controller.setStateForTesting(
        controller.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );
      await tester.pump();

      // Slider must be disabled during CPU turn.
      final sliderWidget =
          tester.widget<Slider>(find.byKey(const Key('carrom_striker_slider')));
      expect(sliderWidget.onChanged, isNull);
    });
  });
}
