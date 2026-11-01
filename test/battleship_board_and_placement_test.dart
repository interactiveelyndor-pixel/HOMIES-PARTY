import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/battleship/battleship_board.dart';
import 'package:classic_ludo/battleship/battleship_computer_player.dart';
import 'package:classic_ludo/battleship/battleship_config.dart';
import 'package:classic_ludo/battleship/battleship_models.dart';

void main() {
  group('BattleshipBoard - Placement Rules', () {
    late BattleshipBoard board;

    setUp(() {
      board = BattleshipBoard();
    });

    test('Valid horizontal placement within bounds succeeds', () {
      final success = board.placeShip(
        ShipType.battleship,
        const Coordinate(0, 0),
        ShipOrientation.horizontal,
      );
      expect(success, isTrue);
      expect(board.placedShipCount, equals(1));
      expect(board.hasShipAt(const Coordinate(0, 0)), isTrue);
      expect(board.hasShipAt(const Coordinate(0, 3)), isTrue);
      expect(board.hasShipAt(const Coordinate(0, 4)), isFalse);
    });

    test('Valid vertical placement within bounds succeeds', () {
      final success = board.placeShip(
        ShipType.destroyer,
        const Coordinate(6, 7),
        ShipOrientation.vertical,
      );
      expect(success, isTrue);
      expect(board.hasShipAt(const Coordinate(6, 7)), isTrue);
      expect(board.hasShipAt(const Coordinate(7, 7)), isTrue);
    });

    test('Invalid placement: out of bounds horizontally rejected', () {
      // Battleship is length 4; at col 5, extends to col 8 (out of bounds on 8×8)
      final canPlace = board.canPlaceShip(
        ShipType.battleship,
        const Coordinate(0, 5),
        ShipOrientation.horizontal,
      );
      expect(canPlace, isFalse);

      final placed = board.placeShip(
        ShipType.battleship,
        const Coordinate(0, 5),
        ShipOrientation.horizontal,
      );
      expect(placed, isFalse);
      expect(board.placedShipCount, equals(0));
    });

    test('Invalid placement: out of bounds vertically rejected', () {
      // Battleship is length 4; at row 5, extends to row 8 (out of bounds on 8×8)
      final canPlace = board.canPlaceShip(
        ShipType.battleship,
        const Coordinate(5, 0),
        ShipOrientation.vertical,
      );
      expect(canPlace, isFalse);

      final placed = board.placeShip(
        ShipType.battleship,
        const Coordinate(5, 0),
        ShipOrientation.vertical,
      );
      expect(placed, isFalse);
      expect(board.placedShipCount, equals(0));
    });

    test('Invalid placement: negative coordinate rejected', () {
      final canPlace = board.canPlaceShip(
        ShipType.destroyer,
        const Coordinate(-1, 0),
        ShipOrientation.horizontal,
      );
      expect(canPlace, isFalse);
    });

    test('Invalid placement: overlap with existing ship rejected', () {
      // Place battleship horizontally at (2, 2). Occupies (2,2), (2,3), (2,4), (2,5)
      board.placeShip(
        ShipType.battleship,
        const Coordinate(2, 2),
        ShipOrientation.horizontal,
      );

      // Attempt to place cruiser vertically at (1, 3). Crosses (2, 3)!
      final canPlace = board.canPlaceShip(
        ShipType.cruiser,
        const Coordinate(1, 3),
        ShipOrientation.vertical,
      );
      expect(canPlace, isFalse);

      final placed = board.placeShip(
        ShipType.cruiser,
        const Coordinate(1, 3),
        ShipOrientation.vertical,
      );
      expect(placed, isFalse);
      expect(board.placedShipCount, equals(1));
    });

    test('Repositioning same ship type is permitted', () {
      board.placeShip(
        ShipType.destroyer,
        const Coordinate(0, 0),
        ShipOrientation.horizontal,
      );
      expect(board.hasShipAt(const Coordinate(0, 0)), isTrue);

      // Move to (5, 5)
      final moved = board.placeShip(
        ShipType.destroyer,
        const Coordinate(5, 5),
        ShipOrientation.vertical,
      );
      expect(moved, isTrue);
      expect(board.hasShipAt(const Coordinate(0, 0)), isFalse);
      expect(board.hasShipAt(const Coordinate(5, 5)), isTrue);
      expect(board.hasShipAt(const Coordinate(6, 5)), isTrue);
      expect(board.placedShipCount, equals(1));
    });

    test('Random fleet placement produces valid, complete, non-overlapping fleet', () {
      for (int seed = 1; seed <= 20; seed++) {
        final testBoard = BattleshipBoard();
        BattleshipComputerPlayer.placeRandomFleet(
          testBoard,
          random: math.Random(seed),
        );

        expect(testBoard.isFleetComplete, isTrue,
            reason: 'Fleet should have ${BattleshipConfig.totalShips} ships with seed $seed');
        expect(testBoard.placedShipCount, equals(BattleshipConfig.totalShips));

        final allCells = <Coordinate>[];
        for (final ship in testBoard.placedShips) {
          expect(ship.coordinates.length, equals(ship.type.length));
          for (final c in ship.coordinates) {
            expect(c.isValid, isTrue);
            allCells.add(c);
          }
        }

        expect(allCells.length, equals(BattleshipConfig.totalFleetCells));
        expect(allCells.toSet().length, equals(BattleshipConfig.totalFleetCells),
            reason: 'Zero overlapping cells with seed $seed');
      }
    });

    test('Reset placement clears all ships', () {
      board.placeShip(
        ShipType.cruiser,
        const Coordinate(0, 0),
        ShipOrientation.horizontal,
      );
      board.clearShips();
      expect(board.placedShipCount, equals(0));
      expect(board.isFleetComplete, isFalse);
    });
  });

  group('BattleshipBoard - Firing, Sinking, and Victory', () {
    late BattleshipBoard board;

    setUp(() {
      board = BattleshipBoard();
      // Place standard 4 ships (8×8 grid)
      board.placeShip(ShipType.destroyer, const Coordinate(0, 0), ShipOrientation.horizontal); // (0,0),(0,1)
      board.placeShip(ShipType.submarine, const Coordinate(2, 0), ShipOrientation.horizontal); // (2,0),(2,1),(2,2)
      board.placeShip(ShipType.cruiser, const Coordinate(4, 0), ShipOrientation.horizontal);   // (4,0),(4,1),(4,2)
      board.placeShip(ShipType.battleship, const Coordinate(6, 0), ShipOrientation.horizontal);// (6,0)..(6,3)
    });

    test('Miss shot records correctly', () {
      final shot = board.receiveShot(const Coordinate(5, 5));
      expect(shot.isHit, isFalse);
      expect(shot.isSunk, isFalse);
      expect(shot.isWin, isFalse);
      expect(board.shotStatusAt(const Coordinate(5, 5)), equals(CellShotStatus.miss));
      expect(board.hasBeenShot(const Coordinate(5, 5)), isTrue);
    });

    test('Hit shot records correctly without sinking if ship has remaining cells', () {
      final shot = board.receiveShot(const Coordinate(0, 0));
      expect(shot.isHit, isTrue);
      expect(shot.isSunk, isFalse);
      expect(shot.isWin, isFalse);
      expect(board.shotStatusAt(const Coordinate(0, 0)), equals(CellShotStatus.hit));
      expect(board.isShipSunk(ShipType.destroyer), isFalse);
    });

    test('Repeated cell shot throws StateError', () {
      board.receiveShot(const Coordinate(1, 1));
      expect(() => board.receiveShot(const Coordinate(1, 1)), throwsStateError);
    });

    test('Out-of-bounds shot throws ArgumentError', () {
      expect(() => board.receiveShot(const Coordinate(-1, 0)), throwsArgumentError);
      expect(() => board.receiveShot(const Coordinate(0, 8)), throwsArgumentError);
    });

    test('Sinking a ship sets isSunk=true and identifies ship name', () {
      board.receiveShot(const Coordinate(0, 0));
      final sinkingShot = board.receiveShot(const Coordinate(0, 1));

      expect(sinkingShot.isHit, isTrue);
      expect(sinkingShot.isSunk, isTrue);
      expect(sinkingShot.sunkShipType, equals(ShipType.destroyer));
      expect(sinkingShot.sunkShipName, equals('Destroyer'));
      expect(board.isShipSunk(ShipType.destroyer), isTrue);
      expect(board.sunkShips, contains(ShipType.destroyer));
      expect(board.remainingShips, isNot(contains(ShipType.destroyer)));
    });

    test('Winning occurs when all 4 ships in the fleet are sunk', () {
      // Sink Destroyer (len 2)
      board.receiveShot(const Coordinate(0, 0));
      board.receiveShot(const Coordinate(0, 1));

      // Sink Submarine (len 3)
      board.receiveShot(const Coordinate(2, 0));
      board.receiveShot(const Coordinate(2, 1));
      board.receiveShot(const Coordinate(2, 2));

      // Sink Cruiser (len 3)
      board.receiveShot(const Coordinate(4, 0));
      board.receiveShot(const Coordinate(4, 1));
      board.receiveShot(const Coordinate(4, 2));

      // Hit first 3 cells of Battleship (len 4)
      board.receiveShot(const Coordinate(6, 0));
      board.receiveShot(const Coordinate(6, 1));
      board.receiveShot(const Coordinate(6, 2));
      expect(board.areAllShipsSunk, isFalse);

      // Final winning shot
      final finalShot = board.receiveShot(const Coordinate(6, 3));
      expect(finalShot.isHit, isTrue);
      expect(finalShot.isSunk, isTrue);
      expect(finalShot.sunkShipType, equals(ShipType.battleship));
      expect(finalShot.isWin, isTrue);
      expect(board.areAllShipsSunk, isTrue);
      expect(board.sunkShips.length, equals(4));
      expect(board.remainingShips.isEmpty, isTrue);
    });
  });
}
