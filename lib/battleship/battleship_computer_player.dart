import 'dart:math' as math;
import 'battleship_config.dart';
import 'battleship_models.dart';
import 'battleship_board.dart';

/// Pure Dart computer AI player for Battleship.
/// Zero Flutter imports.
///
/// FAIR PLAY GUARANTEE:
/// The computer player NEVER reads or inspects the human's board or ship positions.
/// It only receives the public [ShotResult] feedback after firing (hit/miss/sunk).
class BattleshipComputerPlayer {
  final math.Random _random;

  /// Cells already fired upon.
  final Set<Coordinate> _firedCoordinates = {};

  /// Untargeted cells on the checkerboard grid ((row + col) % 2 == 0).
  final List<Coordinate> _checkerboardTargets = [];

  /// Untargeted cells on the remaining grid ((row + col) % 2 != 0).
  final List<Coordinate> _otherTargets = [];

  /// Queue of adjacent cells to target when hunting a known hit.
  final List<Coordinate> _targetQueue = [];

  /// Unresolved hits on the current ship(s).
  final List<Coordinate> _activeHits = [];

  BattleshipComputerPlayer({math.Random? random})
      : _random = random ?? math.Random() {
    _initTargetPools();
  }

  /// Initializes targeting pools for parity / checkerboard hunting.
  void _initTargetPools() {
    for (int r = 0; r < BattleshipConfig.gridSize; r++) {
      for (int c = 0; c < BattleshipConfig.gridSize; c++) {
        final coord = Coordinate(r, c);
        if ((r + c) % 2 == 0) {
          _checkerboardTargets.add(coord);
        } else {
          _otherTargets.add(coord);
        }
      }
    }
  }

  /// Places a random valid fleet of all 5 ships on the provided [board].
  /// Can be used for CPU's own board or for the human player's "Random" button.
  static void placeRandomFleet(
    BattleshipBoard board, {
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    const maxRetries = 200;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      board.clearShips();
      bool allPlaced = true;

      for (final type in ShipType.values) {
        bool placed = false;
        // Try up to 100 placements per ship
        for (int p = 0; p < 100; p++) {
          final orientation = rng.nextBool()
              ? ShipOrientation.horizontal
              : ShipOrientation.vertical;
          final maxRow = orientation == ShipOrientation.vertical
              ? BattleshipConfig.gridSize - type.length
              : BattleshipConfig.gridSize - 1;
          final maxCol = orientation == ShipOrientation.horizontal
              ? BattleshipConfig.gridSize - type.length
              : BattleshipConfig.gridSize - 1;

          final bow = Coordinate(
            rng.nextInt(maxRow + 1),
            rng.nextInt(maxCol + 1),
          );

          if (board.placeShip(type, bow, orientation)) {
            placed = true;
            break;
          }
        }

        if (!placed) {
          allPlaced = false;
          break;
        }
      }

      if (allPlaced && board.isFleetComplete) {
        return;
      }
    }

    // Fallback deterministic placement if extreme RNG collision occurs
    _fallbackPlacement(board);
  }

  static void _fallbackPlacement(BattleshipBoard board) {
    board.clearShips();
    // Deterministic valid layout on 8x8
    board.placeShip(ShipType.battleship, const Coordinate(0, 0), ShipOrientation.horizontal); // len 4: (0,0)-(0,3)
    board.placeShip(ShipType.cruiser, const Coordinate(2, 0), ShipOrientation.horizontal); // len 3: (2,0)-(2,2)
    board.placeShip(ShipType.submarine, const Coordinate(4, 0), ShipOrientation.horizontal); // len 3: (4,0)-(4,2)
    board.placeShip(ShipType.destroyer, const Coordinate(6, 0), ShipOrientation.horizontal); // len 2: (6,0)-(6,1)
  }

  /// Chooses the next target coordinate to fire at.
  /// Never fires at an already fired cell.
  Coordinate getNextShot() {
    // 1. Target mode: if we have candidate cells from previous hits
    while (_targetQueue.isNotEmpty) {
      final candidate = _targetQueue.removeAt(0);
      if (candidate.isValid && !_firedCoordinates.contains(candidate)) {
        return candidate;
      }
    }

    // 2. Hunt mode (checkerboard pattern first)
    final availableChecker = _checkerboardTargets
        .where((c) => !_firedCoordinates.contains(c))
        .toList();
    if (availableChecker.isNotEmpty) {
      final index = _random.nextInt(availableChecker.length);
      return availableChecker[index];
    }

    // 3. Fallback to remaining cells
    final availableOther = _otherTargets
        .where((c) => !_firedCoordinates.contains(c))
        .toList();
    if (availableOther.isNotEmpty) {
      final index = _random.nextInt(availableOther.length);
      return availableOther[index];
    }

    // Safety fallback (should never be reached in normal 10x10 play)
    for (int r = 0; r < BattleshipConfig.gridSize; r++) {
      for (int c = 0; c < BattleshipConfig.gridSize; c++) {
        final coord = Coordinate(r, c);
        if (!_firedCoordinates.contains(coord)) {
          return coord;
        }
      }
    }

    return const Coordinate(0, 0);
  }

  /// Records the shot outcome and updates AI strategy.
  void recordShotResult(ShotResult result) {
    _firedCoordinates.add(result.coordinate);
    _checkerboardTargets.remove(result.coordinate);
    _otherTargets.remove(result.coordinate);

    if (result.isHit) {
      _activeHits.add(result.coordinate);

      if (result.isSunk) {
        // A ship was sunk!
        final sunkLength = result.sunkShipType?.length ?? 1;
        if (_activeHits.length <= sunkLength) {
          // All active hits belonged to this sunk ship
          _activeHits.clear();
          _targetQueue.clear();
        } else {
          // Multiple ships were hit in close proximity;
          // remove the last `sunkLength` hits and re-evaluate queue
          _activeHits.removeRange(
            math.max(0, _activeHits.length - sunkLength),
            _activeHits.length,
          );
          _rebuildTargetQueue();
        }
      } else {
        // Hit, but not sunk yet! Target adjacent cells / continue line
        if (_activeHits.length == 1) {
          // First hit on this ship: enqueue orthogonal neighbors
          final neighbors = result.coordinate.validNeighbors
              .where((c) => !_firedCoordinates.contains(c) && !_targetQueue.contains(c))
              .toList();
          // Shuffle neighbors to avoid predictable directional bias
          neighbors.shuffle(_random);
          _targetQueue.addAll(neighbors);
        } else {
          // Multiple hits: determine axis and extend line
          _targetAlongLine();
        }
      }
    }
  }

  /// Rebuilds the target queue from remaining active hits.
  void _rebuildTargetQueue() {
    _targetQueue.clear();
    if (_activeHits.isEmpty) return;

    if (_activeHits.length == 1) {
      final neighbors = _activeHits.first.validNeighbors
          .where((c) => !_firedCoordinates.contains(c))
          .toList();
      neighbors.shuffle(_random);
      _targetQueue.addAll(neighbors);
    } else {
      _targetAlongLine();
    }
  }

  /// Identifies line orientation from active hits and adds endpoints to front of queue.
  void _targetAlongLine() {
    if (_activeHits.length < 2) return;

    final first = _activeHits.first;
    final isHorizontal = _activeHits.every((c) => c.row == first.row);
    final isVertical = _activeHits.every((c) => c.col == first.col);

    final lineTargets = <Coordinate>[];

    if (isHorizontal) {
      final row = first.row;
      final cols = _activeHits.map((c) => c.col).toList()..sort();
      final minCol = cols.first;
      final maxCol = cols.last;

      final left = Coordinate(row, minCol - 1);
      final right = Coordinate(row, maxCol + 1);

      if (left.isValid && !_firedCoordinates.contains(left)) {
        lineTargets.add(left);
      }
      if (right.isValid && !_firedCoordinates.contains(right)) {
        lineTargets.add(right);
      }
    } else if (isVertical) {
      final col = first.col;
      final rows = _activeHits.map((c) => c.row).toList()..sort();
      final minRow = rows.first;
      final maxRow = rows.last;

      final up = Coordinate(minRow - 1, col);
      final down = Coordinate(maxRow + 1, col);

      if (up.isValid && !_firedCoordinates.contains(up)) {
        lineTargets.add(up);
      }
      if (down.isValid && !_firedCoordinates.contains(down)) {
        lineTargets.add(down);
      }
    }

    if (lineTargets.isNotEmpty) {
      // Prioritize line targets ahead of other queued targets
      _targetQueue.removeWhere((c) => lineTargets.contains(c));
      _targetQueue.insertAll(0, lineTargets);
    } else {
      // Line is blocked at both ends, enqueue neighbors of each hit as fallback
      for (final hit in _activeHits) {
        for (final n in hit.validNeighbors) {
          if (!_firedCoordinates.contains(n) && !_targetQueue.contains(n)) {
            _targetQueue.add(n);
          }
        }
      }
    }
  }

  /// Set of coordinates fired so far (for testing inspection).
  Set<Coordinate> get firedCoordinates => Set.unmodifiable(_firedCoordinates);
}
