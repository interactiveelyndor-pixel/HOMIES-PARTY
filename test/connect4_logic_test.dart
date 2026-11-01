import 'dart:math';
import 'package:classic_ludo/connect4/connect4_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays the given columns alternately (player 1 first).
ConnectFourGame play(List<int> cols) {
  final g = ConnectFourGame();
  for (final c in cols) {
    expect(g.drop(c), isNot(-1), reason: 'column $c should accept a disc');
  }
  return g;
}

void main() {
  group('rules', () {
    test('discs fall to the lowest free row and players alternate', () {
      final g = ConnectFourGame();
      expect(g.drop(3), 5);
      expect(g.current, 2);
      expect(g.drop(3), 4);
      expect(g.board[5][3], 1);
      expect(g.board[4][3], 2);
    });

    test('a full column refuses more discs', () {
      final g = ConnectFourGame();
      for (var i = 0; i < 6; i++) {
        g.drop(0);
      }
      expect(g.canDrop(0), isFalse);
      expect(g.drop(0), -1);
      expect(g.drop(-1), -1);
      expect(g.drop(7), -1);
    });

    test('horizontal win', () {
      final g = play([0, 0, 1, 1, 2, 2, 3]);
      expect(g.winner, 1);
      expect(g.winningCells.length, 4);
    });

    test('vertical win', () {
      final g = play([0, 1, 0, 1, 0, 1, 0]);
      expect(g.winner, 1);
    });

    test('diagonal wins in both directions', () {
      // rising: 1 builds (5,0) (4,1) (3,2) (2,3)
      final up = play([0, 1, 1, 2, 3, 2, 2, 3, 3, 6, 3]);
      expect(up.winner, 1);
      // falling mirror image
      final down = play([6, 5, 5, 4, 3, 4, 4, 3, 3, 0, 3]);
      expect(down.winner, 1);
    });

    test('no moves after the game is over', () {
      final g = play([0, 0, 1, 1, 2, 2, 3]);
      expect(g.drop(4), -1);
      expect(g.isOver, isTrue);
    });

    test('a full board with no line is a draw', () {
      const rowA = [1, 1, 2, 2, 1, 1, 2];
      const rowB = [2, 2, 1, 1, 2, 2, 1];
      final g = ConnectFourGame();
      for (var r = 0; r < ConnectFourGame.rows; r++) {
        for (var c = 0; c < ConnectFourGame.cols; c++) {
          g.board[r][c] = r.isEven ? rowA[c] : rowB[c];
        }
      }
      for (var r = 0; r < ConnectFourGame.rows; r++) {
        for (var c = 0; c < ConnectFourGame.cols; c++) {
          expect(g.lineThrough(r, c), isEmpty, reason: 'cell $r,$c');
        }
      }
      expect(g.isDraw, isTrue);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.drop(0), -1);
    });
  });

  group('computer player', () {
    test('takes an immediate win', () {
      // Player 1 has three in a row at the bottom, needs column 3.
      final g = play([0, 0, 1, 1, 2, 6]); // P1 to move, can win at 3
      expect(ConnectFourAi(Random(1)).pickColumn(g), 3);
    });

    test('blocks the opponent\'s immediate win', () {
      // P2 to move; P1 threatens 3 in a row at the bottom needing column 3.
      final g = play([0, 6, 1, 6, 2]);
      expect(g.current, 2);
      expect(ConnectFourAi(Random(1)).pickColumn(g), 3);
    });

    test('always picks a playable column and finishes games', () {
      for (var seed = 0; seed < 25; seed++) {
        final g = ConnectFourGame();
        final a = ConnectFourAi(Random(seed));
        var moves = 0;
        while (!g.isOver) {
          final col = a.pickColumn(g);
          expect(g.canDrop(col), isTrue);
          g.drop(col);
          moves++;
          expect(moves, lessThanOrEqualTo(42));
        }
      }
    });

    test('does not mutate the real game while thinking', () {
      final g = play([3, 3, 2]);
      final before = [for (final r in g.board) [...r]];
      ConnectFourAi(Random(2)).pickColumn(g);
      expect(g.board, before);
      expect(g.current, 2);
    });
  });
}
