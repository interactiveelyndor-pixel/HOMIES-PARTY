import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/ui/app_back_button.dart';
import 'package:classic_ludo/logic/ludo_controller.dart';
import 'package:classic_ludo/models/game_state.dart';
import 'package:classic_ludo/models/player_color.dart';
import 'package:classic_ludo/screens/home_screen.dart';
import 'package:classic_ludo/screens/ludo_game_screen.dart';
import 'package:classic_ludo/screens/ludo_mode_select_screen.dart';
import 'package:classic_ludo/theme/ludo_theme.dart';
import 'package:classic_ludo/widgets/dice_widget.dart';
import 'package:classic_ludo/widgets/ludo_board_widget.dart';

Widget buildLudoTestApp({
  bool vsComputer = false,
  int playerCount = 2,
  LudoController? controller,
}) {
  return MaterialApp(
    theme: LudoTheme.darkTheme,
    home: LudoGameScreen(
      vsComputer: vsComputer,
      initialPlayerCount: playerCount,
      controller: controller,
    ),
  );
}

void main() {
  group('Ludo - Responsive Layout & Viewports (vs Computer mode)', () {
    testWidgets('Renders cleanly on standard phone (390×844) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Ludo Classic'), findsOneWidget);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
      expect(find.byType(DiceWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on compact phone (360×640) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Ludo Classic'), findsOneWidget);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on tall phone (412×923) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 923 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Ludo Classic'), findsOneWidget);
      expect(find.byType(LudoBoardWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Ludo - Mode Selection & Home Screen Navigation', () {
    testWidgets(
        'Home screen displays Ludo card and navigates to LudoModeSelectScreen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('home_ludo_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_ludo_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details_play')));
      await tester.pumpAndSettle();

      expect(find.byType(LudoModeSelectScreen), findsOneWidget);
      expect(find.byKey(const Key('ludo_mode_multiplayer')), findsOneWidget);
      expect(find.byKey(const Key('ludo_mode_vs_computer')), findsOneWidget);
    });

    testWidgets('Mode select back button returns to home screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('home_ludo_card')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_ludo_card')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('details_play')));

      await tester.pumpAndSettle();

      expect(find.byType(LudoModeSelectScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('ludo_mode_back_button')));
      await tester.pumpAndSettle();

      // Back from the mode screen lands on Game Details; back again for home.
      expect(find.byKey(const Key('details_title')), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        'Tapping Multiplayer (Friends) navigates to Multiplayer LudoGameScreen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const LudoModeSelectScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ludo_mode_multiplayer')));
      await tester.pumpAndSettle();

      expect(find.byType(LudoGameScreen), findsOneWidget);
      // Friends mode top bar shows 4P
      expect(find.text('4P'), findsOneWidget);
    });

    testWidgets(
        'Tapping vs Computer navigates to vs Computer LudoGameScreen with CPU badge',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const LudoModeSelectScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ludo_mode_vs_computer')));
      await tester.pumpAndSettle();

      expect(find.byType(LudoGameScreen), findsOneWidget);
      expect(find.text('2P+CPU'), findsOneWidget);
      expect(find.text('CPU'), findsOneWidget);
    });

    testWidgets('Back button in LudoGameScreen returns to mode select screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LudoTheme.darkTheme,
          home: const LudoModeSelectScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ludo_mode_vs_computer')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ludo_back_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ludo_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LudoModeSelectScreen), findsOneWidget);
    });
  });

  group('Ludo - Dice Positioning (Centered vs Corner)', () {
    testWidgets('In vs Computer mode, dice is centered horizontally in controls',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      final diceCenter = tester.getCenter(find.byKey(const Key('dice_widget')));
      final screenCenter = 390.0 / 2.0;

      // Dice should be centered horizontally on the screen within small margin
      expect((diceCenter.dx - screenCenter).abs(), lessThan(5.0),
          reason: 'Dice must be horizontally centered in vs Computer mode');
    });

    testWidgets('In Multiplayer mode, dice is right-aligned in controls',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 4, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: false, controller: controller));
      await tester.pumpAndSettle();

      final diceCenter = tester.getCenter(find.byKey(const Key('dice_widget')));
      final screenCenter = 390.0 / 2.0;

      // In Multiplayer mode, the dice is positioned to the right of the center
      expect(diceCenter.dx, greaterThan(screenCenter + 30.0),
          reason: 'Dice must remain right-aligned in Multiplayer mode');
    });
  });

  group('Ludo - Human vs Computer Interaction', () {
    testWidgets('Human input is ignored during computer turn', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      // Human (Red) rolls 3 -> no legal moves -> turn passes to Yellow (CPU).
      await controller.rollDice(forcedValue: 3);
      await tester.pump();

      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));

      // Attempting to tap the roll button during CPU turn should do nothing
      final rollButton = tester.widget<ElevatedButton>(find.byKey(const Key('roll_button')));
      expect(rollButton.onPressed, isNull);

      // Attempting to tap dice widget during CPU turn does not trigger roll
      await tester.tap(find.byKey(const Key('dice_widget')));
      await tester.pump();

      // Clean up before test ends
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Human single legal token moves automatically', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      // Red is waiting for roll. Roll 6 -> exactly one legal token (brings 1st token out of base).
      // Wait, in base all 4 tokens are legal to bring out with a 6.
      // To have exactly 1 legal token: 1 token is on track, 3 are in base, roll a non-6 (e.g. 4).
      // Bring token 0 out first with 6:
      await controller.rollDice(forcedValue: 6);
      await tester.pump();
      // Choose token 0
      await controller.selectToken(0);
      await tester.pumpAndSettle();

      // Red earned bonus roll from 6!
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));

      // Roll 3: Only token 0 is on track, tokens 1, 2, 3 are in base and cannot move on a 3.
      // Therefore, exactly ONE legal token exists (token 0), which must auto-move.
      await controller.rollDice(forcedValue: 3);
      // Pump frame to trigger post-frame callback auto-selection
      await tester.pumpAndSettle();

      // Token 0 must have automatically advanced to step 3 without any manual tap!
      final redPlayer = controller.state.players.firstWhere((p) => p.color == PlayerColor.red);
      final token0 = redPlayer.tokens.firstWhere((t) => t.id == 0);
      expect(token0.stepCount, equals(3), reason: 'Token 0 must auto-advance 3 steps');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Human two legal tokens wait for manual tap choice', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = LudoController(playerCount: 2, enableDelays: false);
      await tester.pumpWidget(buildLudoTestApp(vsComputer: true, controller: controller));
      await tester.pumpAndSettle();

      // Bring token 0 out
      await controller.rollDice(forcedValue: 6);
      await tester.pump();
      await controller.selectToken(0);
      await tester.pumpAndSettle();

      // Red rolls 6 again! Now can move token 0 forward OR bring token 1 out of base.
      // So 2+ legal tokens exist!
      await controller.rollDice(forcedValue: 6);
      await tester.pump();

      expect(controller.state.movableTokenIds.length, greaterThan(1));
      // Should NOT auto-select. State must remain waitingForTokenSelection!
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));

      await tester.pumpWidget(const SizedBox());
    });
  });
}
