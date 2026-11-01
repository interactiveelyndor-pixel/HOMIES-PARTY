import 'dart:math';

/// Connect Four rules. Pure Dart, no Flutter imports.
/// Board is [rows] x [cols]; cells are 0 (empty), 1 or 2. Row 0 is the top.
class ConnectFourGame {
  static const rows = 6;
  static const cols = 7;

  final List<List<int>> board;
  int current; // 1 or 2
  int winner = 0; // 0 = none yet
  List<(int, int)> winningCells = const [];
  (int, int)? lastMove;

  ConnectFourGame()
    : board = List.generate(rows, (_) => List.filled(cols, 0)),
      current = 1;

  /// A board received from somewhere else (e.g. the server), for drawing only.
  ConnectFourGame.snapshot({
    required List<List<int>> board,
    required this.current,
    this.winner = 0,
    this.winningCells = const [],
    this.lastMove,
  }) : board = [
         for (final r in board) [...r],
       ];

  ConnectFourGame.copy(ConnectFourGame o)
    : board = [
        for (final r in o.board) [...r],
      ],
      current = o.current,
      winner = o.winner,
      winningCells = o.winningCells,
      lastMove = o.lastMove;

  bool get isDraw => winner == 0 && board[0].every((c) => c != 0);
  bool get isOver => winner != 0 || isDraw;

  bool canDrop(int col) =>
      !isOver && col >= 0 && col < cols && board[0][col] == 0;

  List<int> get playableColumns => [
    for (var c = 0; c < cols; c++)
      if (canDrop(c)) c,
  ];

  /// Drops the current player's disc. Returns the row it landed in, or -1 if
  /// the move is not allowed (game over, bad column, or column full).
  int drop(int col) {
    if (!canDrop(col)) return -1;
    var row = rows - 1;
    while (board[row][col] != 0) {
      row--;
    }
    board[row][col] = current;
    lastMove = (row, col);
    final line = lineThrough(row, col);
    if (line.isNotEmpty) {
      winner = current;
      winningCells = line;
    } else {
      current = current == 1 ? 2 : 1;
    }
    return row;
  }

  static const _dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];

  /// The winning run (4 or more) that includes the given cell, or empty.
  List<(int, int)> lineThrough(int r, int c) {
    final who = board[r][c];
    for (final (dr, dc) in _dirs) {
      final cells = <(int, int)>[(r, c)];
      for (final s in [1, -1]) {
        var rr = r + dr * s, cc = c + dc * s;
        while (rr >= 0 &&
            rr < rows &&
            cc >= 0 &&
            cc < cols &&
            board[rr][cc] == who) {
          cells.add((rr, cc));
          rr += dr * s;
          cc += dc * s;
        }
      }
      if (cells.length >= 4) return cells;
    }
    return const [];
  }
}

/// A modest computer player: wins if it can, blocks if it must, never hands
/// the opponent an immediate win when it can avoid it, and likes the centre.
/// Uses only the public board, like a human would.
class ConnectFourAi {
  final Random _random;
  ConnectFourAi([Random? random]) : _random = random ?? Random();

  int pickColumn(ConnectFourGame game) {
    final options = game.playableColumns;
    assert(options.isNotEmpty);
    final me = game.current;

    int? winning(int player, List<int> cols) {
      for (final c in cols) {
        final g = ConnectFourGame.copy(game)..current = player;
        g.drop(c);
        if (g.winner == player) return c;
      }
      return null;
    }

    final win = winning(me, options);
    if (win != null) return win;
    final block = winning(me == 1 ? 2 : 1, options);
    if (block != null) return block;

    // Avoid moves that let the opponent win on top of them.
    final safe = options.where((c) {
      final g = ConnectFourGame.copy(game)..drop(c);
      if (g.isOver) return true;
      return winning(g.current, g.playableColumns) == null;
    }).toList();
    final pool = safe.isEmpty ? options : safe;

    // Prefer columns near the centre, with a little randomness.
    final best = pool.map((c) => (c - 3).abs()).reduce(min);
    final central = pool.where((c) => (c - 3).abs() <= best + 1).toList();
    return central[_random.nextInt(central.length)];
  }
}
