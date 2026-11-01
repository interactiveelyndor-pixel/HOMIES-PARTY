import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/ui/app_back_button.dart';
import 'package:classic_ludo/battleship/battleship_controller.dart';
import 'package:classic_ludo/battleship/battleship_game_screen.dart';
import 'package:classic_ludo/battleship/battleship_mode_select_screen.dart';
import 'package:classic_ludo/battleship/battleship_models.dart';
import 'package:classic_ludo/battleship/battleship_pass_phone_overlay.dart';
import 'package:classic_ludo/main.dart';
import 'package:classic_ludo/widgets/winner_banner.dart';

void main() {
  group('Battleship - Mode Selection & Home Navigation', () {
    testWidgets('Home screen displays Battleship card and navigates to mode select',
        (tester) async {
      await tester.pumpWidget(const ClassicBoardGamesApp());
      await tester.pumpAndSettle();

      final battleshipCard = find.byKey(const Key('home_battleship_card'));
      expect(battleshipCard, findsOneWidget);

      await tester.ensureVisible(battleshipCard);

      await tester.pumpAndSettle();

      await tester.tap(battleshipCard);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details_play')));
      await tester.pumpAndSettle();

      expect(find.byType(BattleshipModeSelectScreen), findsOneWidget);
      expect(find.text('Classic Battleship'), findsOneWidget);
      expect(find.text('Multiplayer (Friends)'), findsOneWidget);
      expect(find.text('vs Computer'), findsOneWidget);
    });

    testWidgets('Back arrow on mode select returns to home screen',
        (tester) async {
      await tester.pumpWidget(const ClassicBoardGamesApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('home_battleship_card')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_battleship_card')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('details_play')));

      await tester.pumpAndSettle();

      expect(find.byType(BattleshipModeSelectScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('battleship_mode_back_button')));
      await tester.pumpAndSettle();

      // Back from the mode screen lands on Game Details; back again for the list.

      expect(find.byKey(const Key('details_title')), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_battleship_card')), findsOneWidget);
    });

    testWidgets('Mode select opens BattleshipGameScreen and back arrow works',
        (tester) async {
      await tester.pumpWidget(const ClassicBoardGamesApp());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('home_battleship_card')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_battleship_card')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('details_play')));

      await tester.pumpAndSettle();

      // Tap vs Computer
      await tester.tap(find.byKey(const Key('battleship_mode_vs_computer')));
      await tester.pumpAndSettle();

      expect(find.byType(BattleshipGameScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('battleship_game_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(BattleshipModeSelectScreen), findsOneWidget);
    });
  });

  group('Battleship - Placement Phase UI', () {
    testWidgets('Placement controls operate and Start button enables when complete',
        (tester) async {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BattleshipGameScreen(
            gameMode: BattleshipGameMode.vsComputer,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Player 1: Place Fleet'), findsOneWidget);
      expect(find.byKey(const Key('battleship_rotate_button')), findsOneWidget);
      expect(find.byKey(const Key('battleship_random_button')), findsOneWidget);
      expect(find.byKey(const Key('battleship_reset_button')), findsOneWidget);

      // Start button initially disabled
      final startButton = find.byKey(const Key('battleship_start_button'));
      expect(startButton, findsOneWidget);
      final elevatedBefore = tester.widget<ElevatedButton>(startButton);
      expect(elevatedBefore.onPressed, isNull);

      // Tap Rotate button
      expect(find.text('Rotate (H)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('battleship_rotate_button')));
      await tester.pumpAndSettle();
      expect(find.text('Rotate (V)'), findsOneWidget);

      // Tap Random button
      await tester.tap(find.byKey(const Key('battleship_random_button')));
      await tester.pumpAndSettle();

      // Start button should now be enabled
      final elevatedAfter = tester.widget<ElevatedButton>(startButton);
      expect(elevatedAfter.onPressed, isNotNull);

      // Tap Reset button
      await tester.tap(find.byKey(const Key('battleship_reset_button')));
      await tester.pumpAndSettle();
      final elevatedReset = tester.widget<ElevatedButton>(startButton);
      expect(elevatedReset.onPressed, isNull);
    });
  });

  group('Battleship - Multiplayer Pass-the-Phone Overlay', () {
    testWidgets('Pass phone screen appears in multiplayer and dismisses on ready',
        (tester) async {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.multiplayer,
        enableDelays: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BattleshipGameScreen(
            gameMode: BattleshipGameMode.multiplayer,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // P1 places fleet and confirms
      controller.placeRandomFleet();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('battleship_start_button')));
      await tester.pumpAndSettle();

      // Pass phone overlay must be visible
      expect(find.byType(BattleshipPassPhoneOverlay), findsOneWidget);
      expect(find.text('Pass the phone to Player 2'), findsOneWidget);
      expect(find.byKey(const Key('pass_phone_ready_button')), findsOneWidget);

      // Tap ready
      await tester.tap(find.byKey(const Key('pass_phone_ready_button')));
      await tester.pumpAndSettle();

      // Overlay dismissed, now Player 2 placement
      expect(find.byType(BattleshipPassPhoneOverlay), findsNothing);
      expect(find.text('Player 2: Place Fleet'), findsOneWidget);
    });
  });

  group('Battleship - Battle Phase & Winner Dialog', () {
    testWidgets('Firing on target radar displays feedback', (tester) async {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      controller.placeRandomFleet();
      controller.confirmPlacement();

      await tester.pumpWidget(
        MaterialApp(
          home: BattleshipGameScreen(
            gameMode: BattleshipGameMode.vsComputer,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TARGET RADAR'), findsOneWidget);
      expect(find.text('MY FLEET (DEFENSE)'), findsOneWidget);

      // Tap target cell (0, 0)
      final targetCell = find.byKey(const Key('target_cell_0_0'));
      expect(targetCell, findsOneWidget);
      await tester.tap(targetCell);
      await tester.pumpAndSettle();

      // Feedback should now be visible
      expect(find.byKey(const Key('battleship_shot_feedback')), findsOneWidget);
    });

    testWidgets('Winner dialog displays WinnerBanner, Retry, and Home buttons',
        (tester) async {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      controller.placeRandomFleet();
      controller.confirmPlacement();

      await tester.pumpWidget(
        MaterialApp(
          home: BattleshipGameScreen(
            gameMode: BattleshipGameMode.vsComputer,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Force game over by sinking all CPU ships
      final cpuShips = List.of(controller.player2Board.placedShips);
      for (final ship in cpuShips) {
        for (final coord in ship.coordinates) {
          if (controller.phase == BattleshipPhase.battle) {
            controller.fireShot(coord);
          }
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('NAVAL VICTORY!'), findsOneWidget);
      expect(find.byType(WinnerBanner), findsOneWidget);
      expect(find.byKey(const Key('battleship_retry_button')), findsOneWidget);
      expect(find.byKey(const Key('battleship_home_button')), findsOneWidget);

      // Tap Retry restarts the game
      await tester.tap(find.byKey(const Key('battleship_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('Player 1: Place Fleet'), findsOneWidget);
    });
  });

  group('Battleship - Responsive Layout & Viewports', () {
    Future<void> testViewport(WidgetTester tester, Size size) async {
      tester.view.physicalSize = Size(size.width * 2, size.height * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );

      // 1. Placement phase
      await tester.pumpWidget(
        MaterialApp(
          home: BattleshipGameScreen(
            gameMode: BattleshipGameMode.vsComputer,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Placement phase should not overflow on ${size.width}x${size.height}');

      // 2. Battle phase
      controller.placeRandomFleet();
      controller.confirmPlacement();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Battle phase should not overflow on ${size.width}x${size.height}');
    }

    testWidgets('Renders cleanly on compact phone (360×640) with no overflow',
        (tester) async {
      await testViewport(tester, const Size(360, 640));
    });

    testWidgets('Renders cleanly on standard phone (390×844) with no overflow',
        (tester) async {
      await testViewport(tester, const Size(390, 844));
    });

    testWidgets('Renders cleanly on tall phone (412×923) with no overflow',
        (tester) async {
      await testViewport(tester, const Size(412, 923));
    });
  });
}
