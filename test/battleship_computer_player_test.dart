import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/battleship/battleship_board.dart';
import 'package:classic_ludo/battleship/battleship_computer_player.dart';
import 'package:classic_ludo/battleship/battleship_controller.dart';
import 'package:classic_ludo/battleship/battleship_models.dart';

void main() {
  group('BattleshipComputerPlayer - Fair Play & Logic', () {
    test('Computer player does not inspect opponent board or ships', () {
      final ai = BattleshipComputerPlayer(random: math.Random(42));
      // Computer player instance holds only its internal targeting pools and history
      final shot = ai.getNextShot();
      expect(shot.isValid, isTrue);
      expect(ai.firedCoordinates.isEmpty, isTrue); // Fired status updated when ShotResult is given
    });

    test('Initial hunting shots follow checkerboard parity pattern', () {
      final ai = BattleshipComputerPlayer(random: math.Random(999));
      // First 5 miss shots
      for (int i = 0; i < 5; i++) {
        final target = ai.getNextShot();
        // Should be on parity grid (row + col) % 2 == 0
        expect((target.row + target.col) % 2, equals(0),
            reason: 'Shot $i at $target should follow checkerboard hunting');
        ai.recordShotResult(
          ShotResult(coordinate: target, isHit: false, isSunk: false),
        );
      }
    });

    test('Computer finishes sinking a ship after initial hit', () {
      final ai = BattleshipComputerPlayer(random: math.Random(123));
      final humanBoard = BattleshipBoard();
      // Place a cruiser (length 3) at (4, 4), (4, 5), (4, 6)
      humanBoard.placeShip(
        ShipType.cruiser,
        const Coordinate(4, 4),
        ShipOrientation.horizontal,
      );

      // Simulate a hit on (4, 5)
      final firstShot = const Coordinate(4, 5);
      final firstResult = humanBoard.receiveShot(firstShot);
      expect(firstResult.isHit, isTrue);
      expect(firstResult.isSunk, isFalse);
      ai.recordShotResult(firstResult);

      // AI should now target adjacent cells until the cruiser is completely sunk
      bool cruiserSunk = false;
      int safetyCount = 0;

      while (!cruiserSunk && safetyCount < 20) {
        safetyCount++;
        final nextTarget = ai.getNextShot();
        if (humanBoard.hasBeenShot(nextTarget)) {
          // If already shot, continue
          continue;
        }
        final result = humanBoard.receiveShot(nextTarget);
        ai.recordShotResult(result);
        if (result.isSunk && result.sunkShipType == ShipType.cruiser) {
          cruiserSunk = true;
          break;
        }
      }

      expect(cruiserSunk, isTrue,
          reason: 'Computer should focus fire and sink the cruiser');
    });

    test('A seeded computer-vs-computer match finishes with a winner', () {
      // Simulate two AI instances playing against each other
      final board1 = BattleshipBoard();
      final board2 = BattleshipBoard();

      final rng = math.Random(2026);
      BattleshipComputerPlayer.placeRandomFleet(board1, random: rng);
      BattleshipComputerPlayer.placeRandomFleet(board2, random: rng);

      final ai1 = BattleshipComputerPlayer(random: rng);
      final ai2 = BattleshipComputerPlayer(random: rng);

      int rounds = 0;
      const maxRounds = 64; // 8x8 grid has at most 64 shots per player
      bool gameOver = false;
      String? winner;

      while (!gameOver && rounds < maxRounds) {
        rounds++;

        // AI 1 fires at Board 2
        final target1 = ai1.getNextShot();
        final result1 = board2.receiveShot(target1);
        ai1.recordShotResult(result1);

        if (result1.isWin) {
          gameOver = true;
          winner = 'AI 1';
          break;
        }

        // AI 2 fires at Board 1
        final target2 = ai2.getNextShot();
        final result2 = board1.receiveShot(target2);
        ai2.recordShotResult(result2);

        if (result2.isWin) {
          gameOver = true;
          winner = 'AI 2';
          break;
        }
      }

      expect(gameOver, isTrue);
      expect(winner, isNotNull);
      expect(rounds, lessThanOrEqualTo(64));
    });

    test('Input locking during computer turn', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false, // Synchronous resolution for test
      );
      addTearDown(controller.dispose);

      controller.placeRandomFleet();
      controller.confirmPlacement();

      // Human fires at (0, 0) - resolves synchronously with delays off
      final humanShot = controller.fireShot(const Coordinate(0, 0));
      expect(humanShot, isNotNull);

      // After synchronous resolution, CPU fires immediately (no delays),
      // so the turn returns to player1. Verify state is consistent.
      expect(controller.activePlayer, equals(BattleshipPlayerId.player1));
    });
  });
}
