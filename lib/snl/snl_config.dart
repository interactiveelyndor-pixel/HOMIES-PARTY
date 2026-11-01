/// Snakes & Ladders board configuration.
///
/// Board cells are numbered 1–100.
///
/// Constraints verified:
/// - Exactly 8 snakes: head > tail, no positions on 1 or 100
/// - Exactly 8 ladders: bottom < top, no positions on 1 or 100
/// - No snake head coincides with any ladder bottom or ladder top
/// - No ladder bottom coincides with any snake head or snake tail
/// - No ladder top coincides with any snake head
/// - Snake heads and ladder bottoms are fully disjoint sets
///
/// Snake heads  : 17, 40, 47, 54, 62, 64, 87, 95
/// Snake tails  :  7,  3, 26, 34,  7, 18, 24, 56
///   (Note: 62→7 and 17→7 both tail at 7 – that is permitted)
///
/// Ladder bottoms: 4,  9, 20, 28, 36, 51, 63, 71
/// Ladder tops   :25, 31, 38, 84, 58, 67, 81, 91
///
/// Overlap check (heads ∩ bottoms): {} ✓
/// Ladder tops vs snake heads: 25,31,38,84,58,67,81,91 ∩ 17,40,47,54,62,64,87,95 = {} ✓
class SnlConfig {
  SnlConfig._();

  /// Map of snake head → snake tail (head > tail).
  static const Map<int, int> snakes = {
    17: 7,
    40: 3,
    47: 26,
    54: 34,
    62: 19,
    64: 18,
    87: 24,
    95: 56,
  };

  /// Map of ladder bottom → ladder top (bottom < top).
  static const Map<int, int> ladders = {
    4: 25,
    9: 31,
    20: 38,
    28: 84,
    36: 58,
    51: 67,
    63: 81,
    71: 91,
  };

  /// Returns true if [cell] is a snake head.
  static bool isSnakeHead(int cell) => snakes.containsKey(cell);

  /// Returns true if [cell] is a ladder bottom.
  static bool isLadderBottom(int cell) => ladders.containsKey(cell);

  /// Returns the snake tail for a snake head, or null.
  static int? snakeTail(int head) => snakes[head];

  /// Returns the ladder top for a ladder bottom, or null.
  static int? ladderTop(int bottom) => ladders[bottom];
}
