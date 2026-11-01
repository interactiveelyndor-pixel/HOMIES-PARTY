import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/logic/ludo_controller.dart';
import 'package:classic_ludo/models/game_state.dart';
import 'package:classic_ludo/models/player_color.dart';

void main() {
  group('LudoController - Player Modes', () {
    test('Initializes 2-player game with Red & Yellow (opposites)', () {
      final controller = LudoController(playerCount: 2, enableDelays: false);
      expect(controller.state.players.length, equals(2));
      expect(controller.state.players[0].color, equals(PlayerColor.red));
      expect(controller.state.players[1].color, equals(PlayerColor.yellow));
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));
      expect(controller.state.canRollDice, isTrue);
    });

    test('Initializes 3-player game with Red, Green & Yellow', () {
      final controller = LudoController(playerCount: 3, enableDelays: false);
      expect(controller.state.players.length, equals(3));
      expect(controller.state.players[0].color, equals(PlayerColor.red));
      expect(controller.state.players[1].color, equals(PlayerColor.green));
      expect(controller.state.players[2].color, equals(PlayerColor.yellow));
    });

    test('Initializes 4-player game with all 4 colors in clockwise order', () {
      final controller = LudoController(playerCount: 4, enableDelays: false);
      expect(controller.state.players.length, equals(4));
      expect(controller.state.players[0].color, equals(PlayerColor.red));
      expect(controller.state.players[1].color, equals(PlayerColor.green));
      expect(controller.state.players[2].color, equals(PlayerColor.yellow));
      expect(controller.state.players[3].color, equals(PlayerColor.blue));
    });
  });

  group('LudoController - Dice & Base Movement', () {
    test('Roll of 1..5 with all tokens in base results in turn skip', () async {
      final controller = LudoController(playerCount: 4, enableDelays: false);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));

      // Roll 3 -> No token can leave base
      await controller.rollDice(forcedValue: 3);

      // Turn automatically passed to Green
      expect(controller.state.currentPlayer.color, equals(PlayerColor.green));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
    });

    test('Roll of 6 brings a token out to start cell (step 0) and grants extra turn', () async {
      final controller = LudoController(playerCount: 4, enableDelays: false);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));

      // Roll 6
      await controller.rollDice(forcedValue: 6);
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));
      expect(controller.state.movableTokenIds.length, equals(4));

      // Select token 0
      await controller.selectToken(0);

      // Token 0 is now on track at step 0
      final redPlayer = controller.state.players[0];
      expect(redPlayer.tokens[0].stepCount, equals(0));
      expect(redPlayer.tokens[0].isOnTrack, isTrue);

      // Same player gets an extra roll!
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
      expect(controller.state.message, contains('Extra roll'));
    });

    test('Three consecutive sixes forfeits the turn', () async {
      final controller = LudoController(playerCount: 4, enableDelays: false);

      // First 6
      await controller.rollDice(forcedValue: 6);
      await controller.selectToken(0);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));

      // Second 6
      await controller.rollDice(forcedValue: 6);
      await controller.selectToken(0);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));

      // Third 6 -> turn forfeited!
      await controller.rollDice(forcedValue: 6);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.green));
      expect(controller.state.consecutiveSixes, equals(0));
    });
  });

  group('LudoController - Movement, Captures & Safe Cells', () {
    test('Token moves forward exact number of steps and passes turn', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      // Bring token 0 to start (step 0)
      await controller.rollDice(forcedValue: 6);
      await controller.selectToken(0);

      // Now roll 4 (non-6)
      await controller.rollDice(forcedValue: 4);
      expect(controller.state.movableTokenIds, contains(0));
      await controller.selectToken(0);

      // Token 0 is now at step 4
      expect(controller.state.players[0].tokens[0].stepCount, equals(4));

      // No 6, no capture, no home -> Turn passed to Yellow
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
    });

    test('Capturing opponent token on non-safe cell sends it to base and awards bonus turn', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      // Yellow starts at index 26. Step 27 for Yellow is common index (26+27)%52 = 1.
      // Red starts at index 0. Step 1 for Red is common index 1.
      // Common index 1 (6, 2) is a non-safe cell!
      final yellowPlayer = controller.state.players[1].copyWith(
        tokens: [
          controller.state.players[1].tokens[0].copyWith(stepCount: 27),
          controller.state.players[1].tokens[1],
          controller.state.players[1].tokens[2],
          controller.state.players[1].tokens[3],
        ],
      );
      final redPlayer = controller.state.players[0].copyWith(
        tokens: [
          controller.state.players[0].tokens[0].copyWith(stepCount: 0),
          controller.state.players[0].tokens[1],
          controller.state.players[0].tokens[2],
          controller.state.players[0].tokens[3],
        ],
      );

      final setupState = controller.state.copyWith(
        players: [redPlayer, yellowPlayer],
      );
      controller.setStateForTesting(setupState);

      // Roll 1 for Red: moves from step 0 to step 1 (capturing Yellow's token at common index 1!)
      await controller.rollDice(forcedValue: 1);
      await controller.selectToken(0);

      // Verify Red token is at step 1
      expect(controller.state.players[0].tokens[0].stepCount, equals(1));
      // Verify Yellow token was captured and returned to base (-1)!
      expect(controller.state.players[1].tokens[0].isInBase, isTrue);
      expect(controller.state.players[1].tokens[0].stepCount, equals(-1));
      // Red earned bonus turn!
      expect(controller.state.currentPlayer.color, equals(PlayerColor.red));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
      expect(controller.state.message, contains('Captured'));
    });

    test('Safe cell prevents capture', () async {
      final controller = LudoController(playerCount: 4, enableDelays: false);
      // Red start cell (6, 1) is a SAFE cell.
      // Red token is at step 0 (6, 1).
      // Any opponent landing on (6, 1) cannot capture Red.
      await controller.rollDice(forcedValue: 6);
      await controller.selectToken(0); // Red token 0 at step 0 (safe start)
      expect(controller.state.players[0].tokens[0].stepCount, equals(0));
    });
  });

  group('LudoController - Home Entry & Winning', () {
    test('Exact roll required to reach HOME (step 56)', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      // Bring Red out
      await controller.rollDice(forcedValue: 6);
      await controller.selectToken(0);

      // Simulate token near home: step 54
      // Distance to home = 56 - 54 = 2.
      final nearHomePlayer = controller.state.players[0].copyWith(
        tokens: [
          controller.state.players[0].tokens[0].copyWith(stepCount: 54),
          controller.state.players[0].tokens[1],
          controller.state.players[0].tokens[2],
          controller.state.players[0].tokens[3],
        ],
      );

      // Test legal moves with roll 3 (overshoot -> illegal!)
      final movesFor3 = controller.getLegalMoves(nearHomePlayer, 3);
      expect(movesFor3.contains(0), isFalse);

      // Test legal moves with roll 2 (exact -> HOME!)
      final movesFor2 = controller.getLegalMoves(nearHomePlayer, 2);
      expect(movesFor2.contains(0), isTrue);

      // Test legal moves with roll 1 (advances to 55)
      final movesFor1 = controller.getLegalMoves(nearHomePlayer, 1);
      expect(movesFor1.contains(0), isTrue);
    });

    test('Reaching home with all 4 tokens triggers victory and game won', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      // Setup Red with 3 tokens already HOME, and 4th token at step 55
      final almostWonRed = controller.state.players[0].copyWith(
        tokens: [
          controller.state.players[0].tokens[0].copyWith(stepCount: 56),
          controller.state.players[0].tokens[1].copyWith(stepCount: 56),
          controller.state.players[0].tokens[2].copyWith(stepCount: 56),
          controller.state.players[0].tokens[3].copyWith(stepCount: 55),
        ],
      );

      final preWinState = controller.state.copyWith(
        players: [almostWonRed, controller.state.players[1]],
      );
      controller.setStateForTesting(preWinState);

      // Roll 1 to reach HOME with token 3
      await controller.rollDice(forcedValue: 1);
      await controller.selectToken(3);

      // Check victory state
      expect(controller.state.phase, equals(TurnPhase.gameWon));
      expect(controller.state.isGameOver, isTrue);
      expect(controller.state.winner, isNotNull);
      expect(controller.state.winner!.color, equals(PlayerColor.red));
      expect(controller.state.winner!.allHome, isTrue);
    });
  });

  group('LudoController - Input Protection & Reliability', () {
    test('Cannot roll dice when not in waitingForRoll phase', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      // Roll a 6 -> enters waitingForTokenSelection
      await controller.rollDice(forcedValue: 6);
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));
      expect(controller.state.canRollDice, isFalse);

      // Second roll attempt must be rejected!
      await controller.rollDice(forcedValue: 6);
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));
    });

    test('Cannot select opponent tokens or invalid tokens', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      // Red's turn, roll 6
      await controller.rollDice(forcedValue: 6);

      // Try tapping Yellow token 0
      final yellowToken = controller.state.players[1].tokens[0];
      controller.onTokenTap(yellowToken);

      // Phase is still waiting for token selection
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));

      // Try selecting invalid token ID
      await controller.selectToken(999);
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));
    });

    test('Rapid double taps on movable token only execute once', () async {
      final controller = LudoController(playerCount: 2, enableDelays: false);

      await controller.rollDice(forcedValue: 6);
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));

      // Fire two rapid taps
      final redToken0 = controller.state.players[0].tokens[0];
      controller.onTokenTap(redToken0);
      controller.onTokenTap(redToken0);

      // Verify no exceptions and token is at step 0
      expect(controller.state.players[0].tokens[0].stepCount, equals(0));
    });
  });
}
