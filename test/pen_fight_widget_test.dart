import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/ui/app_back_button.dart';
import 'package:classic_ludo/pen_fight/pen_fight_board_widget.dart';
import 'package:classic_ludo/pen_fight/pen_fight_controller.dart';
import 'package:classic_ludo/pen_fight/pen_fight_game_over_dialog.dart';
import 'package:classic_ludo/pen_fight/pen_fight_game_screen.dart';
import 'package:classic_ludo/pen_fight/pen_fight_mode_select_screen.dart';
import 'package:classic_ludo/pen_fight/pen_fight_models.dart';
import 'package:classic_ludo/pen_fight/pen_fight_pen_select_screen.dart';
import 'package:classic_ludo/pen_fight/pen_fight_player_card.dart';
import 'package:classic_ludo/screens/home_screen.dart';
import 'package:classic_ludo/theme/ludo_theme.dart';
import 'package:classic_ludo/widgets/winner_banner.dart';

Widget buildPenFightApp(Widget home) {
  return MaterialApp(
    theme: LudoTheme.darkTheme,
    home: home,
  );
}

void main() {
  group('Pen Fight - Home Navigation & Mode Select Tests', () {
    testWidgets('Home screen displays Pen Fight card and navigates to mode select',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildPenFightApp(const HomeScreen()));
      await tester.pumpAndSettle();

      // Home Screen should display all 5 cards
      expect(find.byKey(const Key('home_ludo_card')), findsOneWidget);
      expect(find.byKey(const Key('home_snl_card')), findsOneWidget);
      expect(find.byKey(const Key('home_carrom_card')), findsOneWidget);
      expect(find.byKey(const Key('home_battleship_card')), findsOneWidget);
      expect(find.byKey(const Key('home_pen_fight_card')), findsOneWidget);

      // Scroll into view & tap Pen Fight card
      await tester.ensureVisible(find.byKey(const Key('home_pen_fight_card')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('home_pen_fight_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_pen_fight_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details_play')));
      await tester.pumpAndSettle();

      // Should be on PenFightModeSelectScreen
      expect(find.byType(PenFightModeSelectScreen), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_mode_2players')), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_mode_vs_computer')), findsOneWidget);
    });

    testWidgets('Mode select back button returns to home screen',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildPenFightApp(const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('home_pen_fight_card')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('home_pen_fight_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_pen_fight_card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('details_play')));
      await tester.pumpAndSettle();

      expect(find.byType(PenFightModeSelectScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('pen_fight_mode_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PenFightModeSelectScreen), findsNothing);
      // Back from the mode screen lands on Game Details; back again for the list.
      expect(find.byKey(const Key('details_title')), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_pen_fight_card')), findsOneWidget);
    });
  });

  group('Pen Fight - Mode Launch & UI Elements Tests', () {
    testWidgets('Play with Friend mode launches with human players',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController(vsComputer: false);
      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(vsComputer: false, controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pen Fight'), findsOneWidget);
      expect(find.byType(PenFightBoardWidget), findsOneWidget);
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_cpu_badge')), findsNothing);
    });

    testWidgets('vs Computer mode displays CPU badge on Player 2 card',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController(vsComputer: true);
      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(vsComputer: true, controller: controller)),
      );
      await tester.pump();

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_cpu_badge')), findsOneWidget);
    });

    testWidgets('How to play rules dialog opens and closes',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController();
      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      // Tap rules button
      await tester.tap(find.byKey(const Key('pen_fight_rules_button')));
      await tester.pumpAndSettle();

      expect(find.text('How to Play Pen Fight'), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_rules_got_it')), findsOneWidget);

      // Close dialog
      await tester.tap(find.byKey(const Key('pen_fight_rules_got_it')));
      await tester.pumpAndSettle();

      expect(find.text('How to Play Pen Fight'), findsNothing);
    });

    testWidgets('Reset match dialog restarts match',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController();
      controller.player1Score = 1;

      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pen_fight_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text('Reset Match?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pen_fight_confirm_reset')));
      await tester.pumpAndSettle();

      expect(controller.player1Score, equals(0));
    });
  });

  group('Pen Fight - Input Locking & Reliability Tests', () {
    testWidgets('Human input is locked during motion',
        (tester) async {
      final controller = PenFightController();
      controller.phase = PenFightPhase.moving;

      expect(controller.canHumanAim(PenFightPlayerId.player1), isFalse);
      expect(controller.canHumanAim(PenFightPlayerId.player2), isFalse);
    });

    testWidgets('Human input is locked for Player 2 during CPU turn in vsComputer mode',
        (tester) async {
      final controller = PenFightController(vsComputer: true);
      controller.currentTurn = PenFightPlayerId.player2;

      expect(controller.canHumanAim(PenFightPlayerId.player2), isFalse);
      expect(controller.canHumanAim(PenFightPlayerId.player1), isFalse);
    });
  });

  group('Pen Fight - Responsive Viewports Tests (No Overflow)', () {
    testWidgets('Renders cleanly on compact phone (360x640) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController();
      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pen Fight'), findsOneWidget);
      expect(find.byType(PenFightBoardWidget), findsOneWidget);
      expect(find.byType(PenFightPlayerCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on standard phone (390x844) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController();
      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pen Fight'), findsOneWidget);
      expect(find.byType(PenFightBoardWidget), findsOneWidget);
      expect(find.byType(PenFightPlayerCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on modern tall phone (412x923) with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 923 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = PenFightController();
      await tester.pumpWidget(
        buildPenFightApp(PenFightGameScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pen Fight'), findsOneWidget);
      expect(find.byType(PenFightBoardWidget), findsOneWidget);
      expect(find.byType(PenFightPlayerCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Pen Fight - Game Over Dialog Tests', () {
    testWidgets('PenFightGameOverDialog reuses WinnerBanner and provides Play Again and Home buttons',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var playedAgain = false;
      var wentHome = false;

      await tester.pumpWidget(
        buildPenFightApp(
          PenFightGameOverDialog(
            winnerName: 'Player 1',
            winnerColor: Colors.purple,
            onPlayAgain: () => playedAgain = true,
            onHome: () => wentHome = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MATCH VICTORY!'), findsOneWidget);
      expect(find.byType(WinnerBanner), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_play_again_button')), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_home_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pen_fight_play_again_button')));
      expect(playedAgain, isTrue);

      await tester.tap(find.byKey(const Key('pen_fight_home_button')));
      expect(wentHome, isTrue);
    });
  });

  group('Pen Fight - Pen Selection Screen Tests', () {
    testWidgets('Pen selection in Friend mode allows both players to pick pen type',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildPenFightApp(const PenFightPenSelectScreen(vsComputer: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Pen'), findsOneWidget);
      expect(find.text('PLAYER 1 · STEP 1 OF 2'), findsOneWidget);

      // Player 1 selects Heavy pen
      await tester.tap(find.byKey(const Key('pen_fight_select_heavy')));
      await tester.pumpAndSettle();

      // Tap Next (Player 2)
      await tester.tap(find.byKey(const Key('pen_fight_select_next_button')));
      await tester.pumpAndSettle();

      // Now Player 2 selects Slim
      expect(find.text('PLAYER 2 · STEP 2 OF 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pen_fight_select_slim')));
      await tester.pumpAndSettle();

      // Tap Start Match -> launches PenFightGameScreen
      await tester.tap(find.byKey(const Key('pen_fight_start_match_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PenFightGameScreen), findsOneWidget);
      expect(find.textContaining('Heavy'), findsWidgets);
      expect(find.textContaining('Slim'), findsWidgets);
    });

    testWidgets('Pen selection in vs Computer mode picks bot pen from seeded random',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final seededRandom = math.Random(1234);
      await tester.pumpWidget(
        buildPenFightApp(PenFightPenSelectScreen(vsComputer: true, random: seededRandom)),
      );
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE YOUR PEN'), findsOneWidget);
      expect(find.textContaining('CPU chose:'), findsOneWidget);

      // Player selects Slim
      await tester.tap(find.byKey(const Key('pen_fight_select_slim')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pen_fight_start_match_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PenFightGameScreen), findsOneWidget);
      expect(find.byKey(const Key('pen_fight_cpu_badge')), findsOneWidget);
    });

    testWidgets('Pen selection screen renders with no overflow on 360x640, 390x844, 412x923',
        (tester) async {
      for (final size in [
        const Size(360 * 2, 640 * 2),
        const Size(390 * 2, 844 * 2),
        const Size(412 * 2, 923 * 2),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2.0;
        await tester.pumpWidget(
          buildPenFightApp(const PenFightPenSelectScreen(vsComputer: false)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
    });
  });
}
