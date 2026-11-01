import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/battleship/battleship_config.dart';
import 'package:classic_ludo/battleship/battleship_controller.dart';
import 'package:classic_ludo/battleship/battleship_models.dart';

void main() {
  group('BattleshipController - Placement & Setup', () {
    test('Cannot confirm placement until all 4 ships are placed', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      expect(controller.phase, equals(BattleshipPhase.placement));
      expect(controller.isCurrentPlacementComplete, isFalse);
      expect(controller.confirmPlacement(), isFalse);
      expect(controller.phase, equals(BattleshipPhase.placement));

      // Place whole fleet
      controller.placeRandomFleet();
      expect(controller.isCurrentPlacementComplete, isTrue);
      expect(controller.confirmPlacement(), isTrue);
      expect(controller.phase, equals(BattleshipPhase.battle));
    });

    test('Rotate orientation toggles horizontal and vertical', () {
      final controller = BattleshipController(enableDelays: false);
      addTearDown(controller.dispose);

      expect(controller.placementOrientation, equals(ShipOrientation.horizontal));
      controller.rotateOrientation();
      expect(controller.placementOrientation, equals(ShipOrientation.vertical));
      controller.rotateOrientation();
      expect(controller.placementOrientation, equals(ShipOrientation.horizontal));
    });

    test('Multiplayer placement handoff requires pass-device step', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.multiplayer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      // Player 1 places fleet
      controller.placeRandomFleet();
      expect(controller.placingPlayer, equals(BattleshipPlayerId.player1));
      controller.confirmPlacement();

      // Must transition to pass-device screen for Player 2
      expect(controller.phase, equals(BattleshipPhase.passDevice));
      expect(controller.placingPlayer, equals(BattleshipPlayerId.player2));

      // Player 2 taps ready
      controller.onPassDeviceReady();
      expect(controller.phase, equals(BattleshipPhase.placement));
      expect(controller.isCurrentPlacementComplete, isFalse);

      // Player 2 places fleet
      controller.placeRandomFleet();
      expect(controller.isCurrentPlacementComplete, isTrue);
      controller.confirmPlacement();

      // Passes back to Player 1 for battle start
      expect(controller.phase, equals(BattleshipPhase.passDevice));
      expect(controller.activePlayer, equals(BattleshipPlayerId.player1));

      // Player 1 taps ready -> Battle starts!
      controller.onPassDeviceReady();
      expect(controller.phase, equals(BattleshipPhase.battle));
    });
  });

  group('BattleshipController - Battle Rules & Privacy', () {
    test('Target board never exposes unhit opponent ships', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      controller.placeRandomFleet();
      controller.confirmPlacement();

      // Opponent (CPU) has 4 placed ships
      expect(controller.player2Board.placedShipCount, equals(BattleshipConfig.totalShips));

      // Initially target board has zero shots
      expect(controller.targetBoardShots.isEmpty, isTrue);

      // Fire a shot at (0, 0)
      controller.fireShot(const Coordinate(0, 0));
      expect(controller.targetBoardShots.length, equals(1));
      expect(controller.targetBoardShots.containsKey(const Coordinate(0, 0)), isTrue);

      // Check that unhit ship locations are NOT exposed in targetBoardShots
      for (final ship in controller.player2Board.placedShips) {
        for (final coord in ship.coordinates) {
          if (coord != const Coordinate(0, 0)) {
            expect(controller.targetBoardShots.containsKey(coord), isFalse);
          }
        }
      }
    });

    test('Repeated cell shot is rejected cleanly and duplicate shot prevented', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      controller.placeRandomFleet();
      controller.confirmPlacement();

      final firstShot = controller.fireShot(const Coordinate(3, 3));
      expect(firstShot, isNotNull);

      // Try firing at same cell again
      final secondShot = controller.fireShot(const Coordinate(3, 3));
      expect(secondShot, isNull);
    });

    test('Multiplayer turn switching with pass device screen', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.multiplayer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      // Setup both fleets
      controller.placeRandomFleet();
      controller.confirmPlacement();
      controller.onPassDeviceReady();
      controller.placeRandomFleet();
      controller.confirmPlacement();
      controller.onPassDeviceReady();

      expect(controller.phase, equals(BattleshipPhase.battle));
      expect(controller.activePlayer, equals(BattleshipPlayerId.player1));

      // Player 1 fires
      final shot = controller.fireShot(const Coordinate(1, 1));
      expect(shot, isNotNull);
      expect(controller.lastShotResult, isNotNull);

      // Player 1 hands over turn
      controller.advanceMultiplayerTurn();
      expect(controller.phase, equals(BattleshipPhase.passDevice));
      expect(controller.activePlayer, equals(BattleshipPlayerId.player2));

      // Player 2 taps ready
      controller.onPassDeviceReady();
      expect(controller.phase, equals(BattleshipPhase.battle));
      expect(controller.activePlayer, equals(BattleshipPlayerId.player2));
    });

    test('Winning condition ends game and records winner', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      controller.placeRandomFleet();
      controller.confirmPlacement();

      // Sink all CPU ships directly by firing at all coordinates of all CPU ships
      final cpuShips = List.of(controller.player2Board.placedShips);
      for (final ship in cpuShips) {
        for (final coord in ship.coordinates) {
          if (controller.phase == BattleshipPhase.battle) {
            controller.fireShot(coord);
          }
        }
      }

      expect(controller.phase, equals(BattleshipPhase.gameOver));
      expect(controller.winner, equals(BattleshipPlayerId.player1));
    });

    test('Restart resets all boards and timers to placement phase', () {
      final controller = BattleshipController(
        gameMode: BattleshipGameMode.vsComputer,
        enableDelays: false,
      );
      addTearDown(controller.dispose);

      controller.placeRandomFleet();
      controller.confirmPlacement();
      controller.fireShot(const Coordinate(0, 0));

      controller.restart();

      expect(controller.phase, equals(BattleshipPhase.placement));
      expect(controller.activePlayer, equals(BattleshipPlayerId.player1));
      expect(controller.player1Board.placedShipCount, equals(0));
      expect(controller.player2Board.placedShipCount, equals(0));
      expect(controller.winner, isNull);
      expect(controller.lastShotResult, isNull);
    });
  });
}
