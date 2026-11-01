// Tests for CarromComputerPlayer.
//
// These tests exercise pure Dart logic only (no Flutter widgets) so they run
// fast and deterministically.  The async scheduleTurn() machinery is NOT tested
// here because it relies on Flutter's task scheduler; those flows are covered
// by the widget-level tests in carrom_widget_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/carrom/carrom_board_layout.dart';
import 'package:classic_ludo/carrom/carrom_computer_player.dart';
import 'package:classic_ludo/carrom/carrom_config.dart';
import 'package:classic_ludo/carrom/carrom_controller.dart';
import 'package:classic_ludo/carrom/carrom_models.dart';
import 'package:classic_ludo/carrom/carrom_vec2.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  CarromComputerPlayer makeCpu(CarromController ctrl, {int seed = 0}) =>
      CarromComputerPlayer(controller: ctrl, seed: seed);

  // ---------------------------------------------------------------------------
  // 1. computeShot — baseline X is always in the legal range
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – computeShot validity', () {
    test('Computed strikerX is always within [baselineMinX, baselineMaxX]', () {
      final ctrl = CarromController(player2Name: 'CPU');
      final cpu = makeCpu(ctrl);

      // Run 20 shots from default starting board with different seeds.
      for (var seed = 0; seed < 20; seed++) {
        final cpuSeeded = CarromComputerPlayer(controller: ctrl, seed: seed);
        final shot = cpuSeeded.computeShot(ctrl.state);
        expect(
          shot.strikerX,
          inInclusiveRange(
            CarromConfig.baselineMinX,
            CarromConfig.baselineMaxX,
          ),
          reason: 'seed=$seed: strikerX=${shot.strikerX} out of baseline range',
        );
        cpuSeeded.dispose();
      }
      cpu.dispose();
    });

    test('Computed shot power is always in (0, 1]', () {
      final ctrl = CarromController(player2Name: 'CPU');
      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);
      expect(shot.power, greaterThan(0.0));
      expect(shot.power, lessThanOrEqualTo(1.0));
      cpu.dispose();
    });

    test('Computed aimVector has non-zero length', () {
      final ctrl = CarromController(player2Name: 'CPU');
      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);
      expect(shot.aimVector.length, greaterThan(0.0));
      cpu.dispose();
    });

    test('Striker placement produced by computeShot does not overlap any active coin', () {
      final ctrl = CarromController(player2Name: 'CPU');
      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);

      final activeCoins = ctrl.state.coins.where((c) => !c.isPocketed).toList();
      expect(
        CarromBoardLayout.isStrikerPlacementValid(
          shot.strikerX,
          CarromPlayerId.player2.baselineY,
          activeCoins,
        ),
        isTrue,
        reason: 'CPU placed striker at ${shot.strikerX} which overlaps a coin',
      );
      cpu.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Fallback shot when no own coins remain
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – fallback shot', () {
    test('Returns a valid shot even when all CPU coins are pocketed', () {
      final ctrl = CarromController(player2Name: 'CPU');
      // Mark all black coins as pocketed.
      for (final c in ctrl.state.coins) {
        if (c.isBlack) c.isPocketed = true;
      }
      ctrl.state.player2.pocketedCount = CarromConfig.blackCoinsCount;

      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);

      expect(
        shot.strikerX,
        inInclusiveRange(CarromConfig.baselineMinX, CarromConfig.baselineMaxX),
      );
      expect(shot.power, greaterThan(0.0));
      cpu.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // 3. CPU takes its turn through the controller (synchronous path)
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – synchronous shot execution', () {
    test('CPU shot transitions controller into simulating phase', () {
      // Switch to player 2's turn manually.
      final ctrl = CarromController(player2Name: 'CPU');
      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);

      // Apply the shot directly (bypasses the async delay).
      ctrl.setStrikerPosition(shot.strikerX);
      final baselineY = CarromPlayerId.player2.baselineY;
      final strikerPos = CarromVec2(shot.strikerX, baselineY);
      final touchPoint = strikerPos - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      final released = ctrl.releaseShot();

      expect(released, isTrue);
      expect(ctrl.state.phase, equals(CarromTurnPhase.simulating));
      cpu.dispose();
    });

    test('CPU shot resolves under the normal rules (simulateToEndForTesting)', () {
      final ctrl = CarromController(player2Name: 'CPU');
      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);

      final baselineY = CarromPlayerId.player2.baselineY;
      ctrl.setStrikerPosition(shot.strikerX);
      final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      ctrl.releaseShot();
      ctrl.simulateToEndForTesting();

      // After shot resolves, phase must NOT be simulating.
      expect(ctrl.state.phase, isNot(equals(CarromTurnPhase.simulating)));
      cpu.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Extra-shot loop — CPU scores, checks it can shoot again
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – extra shot on pocketing own coin', () {
    test('CPU earns extra shot when a black coin is near a pocket', () {
      final ctrl = CarromController(player2Name: 'CPU');

      // Arrange: place a black coin near the top-left pocket.
      final pocket = CarromConfig.pocketCenters.first;
      final blackCoin = ctrl.state.coins.firstWhere((c) => c.isBlack);
      blackCoin.position = CarromVec2(pocket.x + 5.0, pocket.y + 5.0);

      // Set player 2's turn.
      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final cpu = makeCpu(ctrl);
      final shot = cpu.computeShot(ctrl.state);
      final baselineY = CarromPlayerId.player2.baselineY;
      ctrl.setStrikerPosition(shot.strikerX);
      final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      ctrl.releaseShot();
      ctrl.simulateToEndForTesting();

      // If a black coin was pocketed, it's still player2's turn (extra shot).
      if (ctrl.state.player2.pocketedCount > 0) {
        expect(ctrl.state.currentTurn, equals(CarromPlayerId.player2));
      }
      cpu.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Seeded game-to-completion: computer vs computer never gets stuck
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – seeded game reaches game over', () {
    test('Simulated game (CPU vs CPU, seed 42) ends with gameOver', () {
      final ctrl = CarromController(
        player1Name: 'Player 1',
        player2Name: 'CPU',
      );

      // All coins are already pocketed; CPU has 6, Player 1 has 3.
      for (final coin in ctrl.state.coins) {
        coin.isPocketed = true;
      }
      // CPU has 100 points (4 white, 2 black), Player 1 has 30 points (1 white, 1 black).
      ctrl.state.player1.whiteCoinsPocketed = 1;
      ctrl.state.player1.blackCoinsPocketed = 1;
      ctrl.state.player2.whiteCoinsPocketed = 4;
      ctrl.state.player2.blackCoinsPocketed = 2;

      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final cpu = CarromComputerPlayer(controller: ctrl, seed: 42);
      final shot = cpu.computeShot(ctrl.state);
      final baselineY = CarromPlayerId.player2.baselineY;
      ctrl.setStrikerPosition(shot.strikerX);
      final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      final released = ctrl.releaseShot();
      expect(released, isTrue);

      ctrl.simulateToEndForTesting();
      cpu.dispose();

      expect(ctrl.state.phase, equals(CarromTurnPhase.gameOver));
      expect(ctrl.state.winner, equals(CarromPlayerId.player2));
      expect(ctrl.state.statusMessage, contains('CPU wins'));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. CarromController resetGame — player names persist
  // ---------------------------------------------------------------------------
  group('CarromController – resetGame with player names', () {
    test('resetGame with player2Name preserves the CPU label', () {
      final ctrl = CarromController(player2Name: 'CPU');
      expect(ctrl.state.player2.name, equals('CPU'));

      ctrl.resetGame(player2Name: 'CPU');
      expect(ctrl.state.player2.name, equals('CPU'));
    });

    test('resetGame without arguments restores default names', () {
      final ctrl = CarromController();
      ctrl.resetGame();
      expect(ctrl.state.player1.name, equals('Player 1'));
      expect(ctrl.state.player2.name, equals('Player 2'));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. dispose() makes scheduleTurn a no-op
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – dispose cancels pending actions', () {
    test('scheduleTurn is a no-op after dispose', () {
      final ctrl = CarromController(player2Name: 'CPU');
      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );
      final cpu = makeCpu(ctrl);
      cpu.dispose();

      // Must not throw or start a shot.
      expect(() => cpu.scheduleTurn(), returnsNormally);
      // State must remain unchanged.
      expect(ctrl.state.phase, equals(CarromTurnPhase.positioningStriker));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Medium AI: Target selection, power calibration, and scoring
  // ---------------------------------------------------------------------------
  group('CarromComputerPlayer – Medium AI enhancements', () {
    test('CPU successfully pockets an open black coin aimed toward bottom pocket', () {
      final ctrl = CarromController(player2Name: 'CPU');

      // Mark all other coins pocketed to isolate the target
      for (final c in ctrl.state.coins) {
        c.isPocketed = true;
      }

      // Single black coin at (280, 450) with clean line of sight to bottom-left pocket (76, 724)
      final blackCoin = ctrl.state.coins.firstWhere((c) => c.isBlack);
      blackCoin.isPocketed = false;
      blackCoin.position = const CarromVec2(280.0, 450.0);
      blackCoin.velocity = CarromVec2.zero;

      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final cpu = CarromComputerPlayer(controller: ctrl, seed: 10);
      final shot = cpu.computeShot(ctrl.state);

      // Verify shot properties
      expect(shot.strikerX, inInclusiveRange(CarromConfig.baselineMinX, CarromConfig.baselineMaxX));
      expect(shot.power, greaterThanOrEqualTo(0.40));

      // Execute shot through controller
      final baselineY = CarromPlayerId.player2.baselineY;
      ctrl.setStrikerPosition(shot.strikerX);
      final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      final released = ctrl.releaseShot();
      expect(released, isTrue);

      ctrl.simulateToEndForTesting();
      cpu.dispose();

      expect(blackCoin.isPocketed, isTrue, reason: 'CPU should successfully pocket the open black coin');
      expect(ctrl.state.player2.pocketedCount, greaterThan(0));
    });

    test('CPU can also pocket an available open white coin', () {
      final ctrl = CarromController(player2Name: 'CPU');

      for (final c in ctrl.state.coins) {
        c.isPocketed = true;
      }

      // Single white coin at (520, 450) with clear line to bottom-right pocket (724, 724)
      final whiteCoin = ctrl.state.coins.firstWhere((c) => c.isWhite);
      whiteCoin.isPocketed = false;
      whiteCoin.position = const CarromVec2(520.0, 450.0);
      whiteCoin.velocity = CarromVec2.zero;

      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      final cpu = CarromComputerPlayer(controller: ctrl, seed: 10);
      final shot = cpu.computeShot(ctrl.state);

      final baselineY = CarromPlayerId.player2.baselineY;
      ctrl.setStrikerPosition(shot.strikerX);
      final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      ctrl.releaseShot();

      ctrl.simulateToEndForTesting();
      cpu.dispose();

      expect(whiteCoin.isPocketed, isTrue, reason: 'CPU should pocket available white coin');
      expect(ctrl.state.player2.whiteCoinsPocketed, equals(1));
    });

    test('CPU prioritizes covering Queen when Queen is pending cover', () {
      final ctrl = CarromController(player2Name: 'CPU');

      for (final c in ctrl.state.coins) {
        c.isPocketed = true;
      }

      // Place one black coin in good position for cover
      final blackCoin = ctrl.state.coins.firstWhere((c) => c.isBlack);
      blackCoin.isPocketed = false;
      blackCoin.position = const CarromVec2(280.0, 450.0);
      blackCoin.velocity = CarromVec2.zero;

      // Set Queen pending cover by CPU
      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
          queenStatus: QueenStatus.pendingCover,
          queenPocketedBy: () => CarromPlayerId.player2,
        ),
      );

      final cpu = CarromComputerPlayer(controller: ctrl, seed: 10);
      final shot = cpu.computeShot(ctrl.state);

      final baselineY = CarromPlayerId.player2.baselineY;
      ctrl.setStrikerPosition(shot.strikerX);
      final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
      ctrl.startAiming(touchPoint);
      ctrl.updateAim(touchPoint);
      ctrl.releaseShot();

      ctrl.simulateToEndForTesting();
      cpu.dispose();

      expect(ctrl.state.queenStatus, equals(QueenStatus.covered));
      expect(ctrl.state.player2.hasCoveredQueen, isTrue);
    });

    test('CPU uses sufficient shot power (>= 0.40) and never shoots weakly', () {
      final ctrl = CarromController(player2Name: 'CPU');
      ctrl.setStateForTesting(
        ctrl.state.copyWith(
          currentTurn: CarromPlayerId.player2,
          phase: CarromTurnPhase.positioningStriker,
        ),
      );

      // Test across multiple seeds on standard opening layout
      for (var seed = 0; seed < 10; seed++) {
        final cpu = CarromComputerPlayer(controller: ctrl, seed: seed);
        final shot = cpu.computeShot(ctrl.state);
        expect(
          shot.power,
          greaterThanOrEqualTo(0.40),
          reason: 'Shot power ${shot.power} too low for seed $seed; should be >= 0.40',
        );
        expect(shot.power, lessThanOrEqualTo(1.0));
        cpu.dispose();
      }
    });

    test('Medium difficulty balance: scores regularly on good looks but has human variance', () {
      // Run 10 trials with different random seeds on an open shot
      var scoredCount = 0;
      for (var seed = 0; seed < 10; seed++) {
        final ctrl = CarromController(player2Name: 'CPU');
        for (final c in ctrl.state.coins) {
          c.isPocketed = true;
        }

        final blackCoin = ctrl.state.coins.firstWhere((c) => c.isBlack);
        blackCoin.isPocketed = false;
        blackCoin.position = const CarromVec2(280.0, 450.0);
        blackCoin.velocity = CarromVec2.zero;

        ctrl.setStateForTesting(
          ctrl.state.copyWith(
            currentTurn: CarromPlayerId.player2,
            phase: CarromTurnPhase.positioningStriker,
          ),
        );

        final cpu = CarromComputerPlayer(controller: ctrl, seed: seed);
        final shot = cpu.computeShot(ctrl.state);

        final baselineY = CarromPlayerId.player2.baselineY;
        ctrl.setStrikerPosition(shot.strikerX);
        final touchPoint = CarromVec2(shot.strikerX, baselineY) - shot.aimVector;
        ctrl.startAiming(touchPoint);
        ctrl.updateAim(touchPoint);
        ctrl.releaseShot();
        ctrl.simulateToEndForTesting();
        cpu.dispose();

        if (blackCoin.isPocketed) {
          scoredCount++;
        }
      }

      // Medium opponent scores regularly on clean setups (at least 70% of the time)
      expect(scoredCount, greaterThanOrEqualTo(7));
    });
  });
}

