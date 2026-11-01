import 'board_coordinate.dart';
import 'player_color.dart';

class BoardPath {
  BoardPath._();

  static const int totalStepsToHome = 56;

  /// The 52 continuous common path coordinates on a 15x15 board.
  static const List<BoardCoordinate> commonTrack = [
    // 0..4: Left arm upper row (moving right)
    BoardCoordinate(6, 1), // 0: Red Start
    BoardCoordinate(6, 2), // 1
    BoardCoordinate(6, 3), // 2
    BoardCoordinate(6, 4), // 3
    BoardCoordinate(6, 5), // 4
    // 5..10: Top arm left column (moving up)
    BoardCoordinate(5, 6), // 5
    BoardCoordinate(4, 6), // 6
    BoardCoordinate(3, 6), // 7
    BoardCoordinate(2, 6), // 8: Star Safe
    BoardCoordinate(1, 6), // 9
    BoardCoordinate(0, 6), // 10
    // 11..12: Top turn
    BoardCoordinate(0, 7), // 11
    BoardCoordinate(0, 8), // 12
    // 13..17: Top arm right column (moving down)
    BoardCoordinate(1, 8), // 13: Green Start
    BoardCoordinate(2, 8), // 14
    BoardCoordinate(3, 8), // 15
    BoardCoordinate(4, 8), // 16
    BoardCoordinate(5, 8), // 17
    // 18..23: Right arm top row (moving right)
    BoardCoordinate(6, 9), // 18
    BoardCoordinate(6, 10), // 19
    BoardCoordinate(6, 11), // 20
    BoardCoordinate(6, 12), // 21: Star Safe
    BoardCoordinate(6, 13), // 22
    BoardCoordinate(6, 14), // 23
    // 24..25: Right turn
    BoardCoordinate(7, 14), // 24
    BoardCoordinate(8, 14), // 25
    // 26..30: Right arm bottom row (moving left)
    BoardCoordinate(8, 13), // 26: Yellow Start
    BoardCoordinate(8, 12), // 27
    BoardCoordinate(8, 11), // 28
    BoardCoordinate(8, 10), // 29
    BoardCoordinate(8, 9), // 30
    // 31..36: Bottom arm right column (moving down)
    BoardCoordinate(9, 8), // 31
    BoardCoordinate(10, 8), // 32
    BoardCoordinate(11, 8), // 33
    BoardCoordinate(12, 8), // 34: Star Safe
    BoardCoordinate(13, 8), // 35
    BoardCoordinate(14, 8), // 36
    // 37..38: Bottom turn
    BoardCoordinate(14, 7), // 37
    BoardCoordinate(14, 6), // 38
    // 39..43: Bottom arm left column (moving up)
    BoardCoordinate(13, 6), // 39: Blue Start
    BoardCoordinate(12, 6), // 40
    BoardCoordinate(11, 6), // 41
    BoardCoordinate(10, 6), // 42
    BoardCoordinate(9, 6), // 43
    // 44..49: Left arm bottom row (moving left)
    BoardCoordinate(8, 5), // 44
    BoardCoordinate(8, 4), // 45
    BoardCoordinate(8, 3), // 46
    BoardCoordinate(8, 2), // 47: Star Safe
    BoardCoordinate(8, 1), // 48
    BoardCoordinate(8, 0), // 49
    // 50..51: Left turn
    BoardCoordinate(7, 0), // 50
    BoardCoordinate(6, 0), // 51
  ];

  /// Start track index for each player color.
  static int getStartIndex(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return 0;
      case PlayerColor.green:
        return 13;
      case PlayerColor.yellow:
        return 26;
      case PlayerColor.blue:
        return 39;
    }
  }

  /// Private home stretches (steps 51..55) for each color.
  static const Map<PlayerColor, List<BoardCoordinate>> homeStretches = {
    PlayerColor.red: [
      BoardCoordinate(7, 1),
      BoardCoordinate(7, 2),
      BoardCoordinate(7, 3),
      BoardCoordinate(7, 4),
      BoardCoordinate(7, 5),
    ],
    PlayerColor.green: [
      BoardCoordinate(1, 7),
      BoardCoordinate(2, 7),
      BoardCoordinate(3, 7),
      BoardCoordinate(4, 7),
      BoardCoordinate(5, 7),
    ],
    PlayerColor.yellow: [
      BoardCoordinate(7, 13),
      BoardCoordinate(7, 12),
      BoardCoordinate(7, 11),
      BoardCoordinate(7, 10),
      BoardCoordinate(7, 9),
    ],
    PlayerColor.blue: [
      BoardCoordinate(13, 7),
      BoardCoordinate(12, 7),
      BoardCoordinate(11, 7),
      BoardCoordinate(10, 7),
      BoardCoordinate(9, 7),
    ],
  };

  /// Center Home Goal coordinates for each color.
  static const Map<PlayerColor, BoardCoordinate> homeGoals = {
    PlayerColor.red: BoardCoordinate(7, 6),
    PlayerColor.green: BoardCoordinate(6, 7),
    PlayerColor.yellow: BoardCoordinate(7, 8),
    PlayerColor.blue: BoardCoordinate(8, 7),
  };

  /// The 8 safe cells on the board (4 start cells + 4 star cells).
  static final Set<BoardCoordinate> safeCoordinates = {
    // 4 Start safe cells
    const BoardCoordinate(6, 1), // Red Start
    const BoardCoordinate(1, 8), // Green Start
    const BoardCoordinate(8, 13), // Yellow Start
    const BoardCoordinate(13, 6), // Blue Start
    // 4 Star safe cells
    const BoardCoordinate(2, 6), // Red arm Star
    const BoardCoordinate(6, 12), // Green arm Star
    const BoardCoordinate(12, 8), // Yellow arm Star
    const BoardCoordinate(8, 2), // Blue arm Star
  };

  /// 4 Star cell coordinates.
  static final Set<BoardCoordinate> starCoordinates = {
    const BoardCoordinate(2, 6),
    const BoardCoordinate(6, 12),
    const BoardCoordinate(12, 8),
    const BoardCoordinate(8, 2),
  };

  /// Checks if a given coordinate is safe from capture.
  static bool isSafe(BoardCoordinate coord) {
    if (safeCoordinates.contains(coord)) return true;
    // Any coordinate in home stretch or home goal is also completely safe
    for (final stretch in homeStretches.values) {
      if (stretch.contains(coord)) return true;
    }
    return homeGoals.values.contains(coord);
  }

  /// Returns the exact board coordinate for a token at a given stepCount (0..56).
  static BoardCoordinate getCoordinate(PlayerColor color, int stepCount) {
    assert(stepCount >= 0 && stepCount <= totalStepsToHome,
        'stepCount must be between 0 and 56');

    if (stepCount == totalStepsToHome) {
      return homeGoals[color]!;
    }

    if (stepCount >= 51) {
      final stretchIndex = stepCount - 51;
      return homeStretches[color]![stretchIndex];
    }

    final startIndex = getStartIndex(color);
    final trackIndex = (startIndex + stepCount) % 52;
    return commonTrack[trackIndex];
  }

  /// Base slot offsets in grid units (0..14).
  static List<(double, double)> getBaseSlotCoordinates(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return const [
          (1.8, 1.8),
          (1.8, 4.2),
          (4.2, 1.8),
          (4.2, 4.2),
        ];
      case PlayerColor.green:
        return const [
          (1.8, 10.8),
          (1.8, 13.2),
          (4.2, 10.8),
          (4.2, 13.2),
        ];
      case PlayerColor.yellow:
        return const [
          (10.8, 10.8),
          (10.8, 13.2),
          (13.2, 10.8),
          (13.2, 13.2),
        ];
      case PlayerColor.blue:
        return const [
          (10.8, 1.8),
          (10.8, 4.2),
          (13.2, 1.8),
          (13.2, 4.2),
        ];
    }
  }
}
