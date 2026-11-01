/// Centralized configuration for Battleship game.
/// Pure Dart: zero Flutter imports.
class BattleshipConfig {
  BattleshipConfig._();

  /// Board dimensions: 8×8 grid.
  static const int gridSize = 8;

  /// Fleet ship lengths (4 ships total).
  static const int battleshipLength = 4;
  static const int cruiserLength = 3;
  static const int submarineLength = 3;
  static const int destroyerLength = 2;

  /// Total number of ships in a fleet.
  static const int totalShips = 4;

  /// Total occupied cells by an entire fleet (4 + 3 + 3 + 2 = 12).
  static const int totalFleetCells = 12;

  /// Delay in milliseconds before computer fires its shot.
  static const int computerShotDelayMs = 700;

  /// Duration in milliseconds for missile animation flight.
  static const int missileAnimationDurationMs = 400;

  /// Short delay in milliseconds to display shot result before passing device in multiplayer.
  static const int shotFeedbackDurationMs = 1200;
}
