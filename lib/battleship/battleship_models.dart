import 'battleship_config.dart';

/// Represents a grid coordinate on the 8×8 board.
/// Pure Dart: zero Flutter imports.
class Coordinate {
  final int row;
  final int col;

  const Coordinate(this.row, this.col);

  /// Validates that coordinate is within 8×8 bounds.
  bool get isValid =>
      row >= 0 &&
      row < BattleshipConfig.gridSize &&
      col >= 0 &&
      col < BattleshipConfig.gridSize;

  /// Returns orthogonal adjacent neighbors (Up, Down, Left, Right) that are in bounds.
  List<Coordinate> get validNeighbors {
    final list = <Coordinate>[];
    final candidates = [
      Coordinate(row - 1, col), // Up
      Coordinate(row + 1, col), // Down
      Coordinate(row, col - 1), // Left
      Coordinate(row, col + 1), // Right
    ];
    for (final c in candidates) {
      if (c.isValid) list.add(c);
    }
    return list;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coordinate &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// Types of ships in standard Battleship fleet (4 ships).
enum ShipType {
  battleship('Battleship', BattleshipConfig.battleshipLength),
  cruiser('Cruiser', BattleshipConfig.cruiserLength),
  submarine('Submarine', BattleshipConfig.submarineLength),
  destroyer('Destroyer', BattleshipConfig.destroyerLength);

  final String displayName;
  final int length;

  const ShipType(this.displayName, this.length);
}

/// Orientation of a ship on the grid.
enum ShipOrientation {
  horizontal,
  vertical;

  ShipOrientation get rotated =>
      this == horizontal ? vertical : horizontal;
}

/// Represents a placed ship on the grid.
class PlacedShip {
  final ShipType type;
  final Coordinate bow;
  final ShipOrientation orientation;
  final List<Coordinate> coordinates;

  PlacedShip({
    required this.type,
    required this.bow,
    required this.orientation,
  }) : coordinates = _calculateCoordinates(type, bow, orientation);

  static List<Coordinate> _calculateCoordinates(
    ShipType type,
    Coordinate bow,
    ShipOrientation orientation,
  ) {
    final coords = <Coordinate>[];
    for (int i = 0; i < type.length; i++) {
      if (orientation == ShipOrientation.horizontal) {
        coords.add(Coordinate(bow.row, bow.col + i));
      } else {
        coords.add(Coordinate(bow.row + i, bow.col));
      }
    }
    return List.unmodifiable(coords);
  }

  /// Checks if this ship occupies the given coordinate.
  bool occupies(Coordinate c) => coordinates.contains(c);

  /// Checks if this ship is completely sunk given a set of hit coordinates.
  bool isSunk(Iterable<Coordinate> hits) {
    final hitSet = hits is Set<Coordinate> ? hits : hits.toSet();
    return coordinates.every((c) => hitSet.contains(c));
  }
}

/// Status of a cell on the board.
enum CellShotStatus {
  unshot,
  miss,
  hit,
}

/// Result of firing a shot at a coordinate.
class ShotResult {
  final Coordinate coordinate;
  final bool isHit;
  final bool isSunk;
  final ShipType? sunkShipType;
  final String? sunkShipName;
  final PlacedShip? sunkShip;
  final bool isWin;

  const ShotResult({
    required this.coordinate,
    required this.isHit,
    this.isSunk = false,
    this.sunkShipType,
    this.sunkShipName,
    this.sunkShip,
    this.isWin = false,
  });

  @override
  String toString() =>
      'ShotResult(coord: $coordinate, hit: $isHit, sunk: $isSunk, sunkShip: $sunkShipName, win: $isWin)';
}

/// Player identifiers.
enum BattleshipPlayerId {
  player1,
  player2;

  BattleshipPlayerId get opponent =>
      this == player1 ? player2 : player1;
}

/// Battleship game mode.
enum BattleshipGameMode {
  multiplayer,
  vsComputer,
}

/// Phases of the Battleship gameplay lifecycle.
enum BattleshipPhase {
  /// Players are placing their 4 ships.
  placement,

  /// Full-screen "Pass the phone to Player X. Tap when ready" screen.
  passDevice,

  /// Active firing battle.
  battle,

  /// One fleet is completely sunk.
  gameOver,
}
