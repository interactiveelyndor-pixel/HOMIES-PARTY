import 'battleship_config.dart';
import 'battleship_models.dart';

/// Represents a player's private 8×8 grid in Battleship.
/// Pure Dart: zero Flutter imports.
class BattleshipBoard {
  final Map<ShipType, PlacedShip> _ships = {};
  final Map<Coordinate, CellShotStatus> _receivedShots = {};

  BattleshipBoard();

  /// Map of placed ships by ship type.
  Map<ShipType, PlacedShip> get ships => Map.unmodifiable(_ships);

  /// List of placed ships.
  List<PlacedShip> get placedShips => _ships.values.toList();

  /// Shots received on this board.
  Map<Coordinate, CellShotStatus> get receivedShots =>
      Map.unmodifiable(_receivedShots);

  /// Number of placed ships.
  int get placedShipCount => _ships.length;

  /// True when all 4 fleet ships have been placed.
  bool get isFleetComplete => _ships.length == BattleshipConfig.totalShips;

  /// Checks if a ship can be placed at the given bow and orientation.
  bool canPlaceShip(
    ShipType type,
    Coordinate bow,
    ShipOrientation orientation,
  ) {
    final candidate = PlacedShip(
      type: type,
      bow: bow,
      orientation: orientation,
    );

    // Ensure all coordinates are strictly within 8×8 bounds.
    for (final coord in candidate.coordinates) {
      if (!coord.isValid) return false;
    }

    // Ensure no overlap with other placed ships (excluding self if repositioning).
    for (final entry in _ships.entries) {
      if (entry.key == type) continue;
      for (final candidateCoord in candidate.coordinates) {
        if (entry.value.occupies(candidateCoord)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Places a ship. Returns true if successfully placed, false if invalid.
  bool placeShip(
    ShipType type,
    Coordinate bow,
    ShipOrientation orientation,
  ) {
    if (!canPlaceShip(type, bow, orientation)) {
      return false;
    }
    _ships[type] = PlacedShip(
      type: type,
      bow: bow,
      orientation: orientation,
    );
    return true;
  }

  /// Removes a specific ship from the board.
  void removeShip(ShipType type) {
    _ships.remove(type);
  }

  /// Clears all placed ships and shots.
  void clear() {
    _ships.clear();
    _receivedShots.clear();
  }

  /// Clears ships only (resets placement).
  void clearShips() {
    _ships.clear();
  }

  /// Returns the placed ship occupying the given coordinate, or null if empty.
  PlacedShip? shipAt(Coordinate c) {
    for (final ship in _ships.values) {
      if (ship.occupies(c)) return ship;
    }
    return null;
  }

  /// True if a ship is located at [c].
  bool hasShipAt(Coordinate c) => shipAt(c) != null;

  /// True if this cell has already received a shot.
  bool hasBeenShot(Coordinate c) => _receivedShots.containsKey(c);

  /// Returns the shot status at [c].
  CellShotStatus shotStatusAt(Coordinate c) =>
      _receivedShots[c] ?? CellShotStatus.unshot;

  /// Set of all coordinates that were hit on this board.
  Set<Coordinate> get hitCoordinates => _receivedShots.entries
      .where((e) => e.value == CellShotStatus.hit)
      .map((e) => e.key)
      .toSet();

  /// Set of all coordinates that were misses on this board.
  Set<Coordinate> get missCoordinates => _receivedShots.entries
      .where((e) => e.value == CellShotStatus.miss)
      .map((e) => e.key)
      .toSet();

  /// Checks if a specific placed ship is sunk.
  bool isShipSunk(ShipType type) {
    final ship = _ships[type];
    if (ship == null) return false;
    return ship.isSunk(hitCoordinates);
  }

  /// List of ship types that are currently sunk.
  List<ShipType> get sunkShips =>
      _ships.keys.where(isShipSunk).toList();

  /// List of ship types that are still afloat.
  List<ShipType> get remainingShips =>
      _ships.keys.where((t) => !isShipSunk(t)).toList();

  /// True if the entire fleet is sunk.
  bool get areAllShipsSunk {
    if (!isFleetComplete) return false;
    return _ships.values.every((ship) => ship.isSunk(hitCoordinates));
  }

  /// List of placed ships that are completely sunk.
  /// Strictly reveals only sunk ships; unsunk ships are never included.
  List<PlacedShip> get sunkPlacedShips =>
      _ships.values.where((s) => s.isSunk(hitCoordinates)).toList();

  /// Receives an opponent's shot at [target].
  /// Returns a [ShotResult].
  /// Throws [StateError] or [ArgumentError] if cell already shot or out of bounds.
  ShotResult receiveShot(Coordinate target) {
    if (!target.isValid) {
      throw ArgumentError('Coordinate $target is out of bounds');
    }
    if (hasBeenShot(target)) {
      throw StateError('Coordinate $target has already been shot');
    }

    final ship = shipAt(target);
    if (ship != null) {
      _receivedShots[target] = CellShotStatus.hit;
      final hits = hitCoordinates;
      final shipSunk = ship.isSunk(hits);
      final allSunk = areAllShipsSunk;

      return ShotResult(
        coordinate: target,
        isHit: true,
        isSunk: shipSunk,
        sunkShipType: shipSunk ? ship.type : null,
        sunkShipName: shipSunk ? ship.type.displayName : null,
        sunkShip: shipSunk ? ship : null,
        isWin: allSunk,
      );
    } else {
      _receivedShots[target] = CellShotStatus.miss;
      return ShotResult(
        coordinate: target,
        isHit: false,
        isSunk: false,
        isWin: false,
      );
    }
  }
}
