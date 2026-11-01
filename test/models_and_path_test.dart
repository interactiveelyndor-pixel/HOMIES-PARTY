import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/models/board_coordinate.dart';
import 'package:classic_ludo/models/board_path.dart';
import 'package:classic_ludo/models/player.dart';
import 'package:classic_ludo/models/player_color.dart';
import 'package:classic_ludo/models/token.dart';

void main() {
  group('BoardPath & Coordinate Tests', () {
    test('Common track has exactly 52 valid coordinates', () {
      expect(BoardPath.commonTrack.length, equals(52));
      for (final coord in BoardPath.commonTrack) {
        expect(coord.row, inInclusiveRange(0, 14));
        expect(coord.col, inInclusiveRange(0, 14));
      }
    });

    test('Start indices are correctly spaced by 13 cells', () {
      expect(BoardPath.getStartIndex(PlayerColor.red), equals(0));
      expect(BoardPath.getStartIndex(PlayerColor.green), equals(13));
      expect(BoardPath.getStartIndex(PlayerColor.yellow), equals(26));
      expect(BoardPath.getStartIndex(PlayerColor.blue), equals(39));
    });

    test('Start coordinates match standard Ludo positions', () {
      expect(
        BoardPath.getCoordinate(PlayerColor.red, 0),
        equals(const BoardCoordinate(6, 1)),
      );
      expect(
        BoardPath.getCoordinate(PlayerColor.green, 0),
        equals(const BoardCoordinate(1, 8)),
      );
      expect(
        BoardPath.getCoordinate(PlayerColor.yellow, 0),
        equals(const BoardCoordinate(8, 13)),
      );
      expect(
        BoardPath.getCoordinate(PlayerColor.blue, 0),
        equals(const BoardCoordinate(13, 6)),
      );
    });

    test('Safe cells include all 4 starts and 4 stars', () {
      expect(BoardPath.safeCoordinates.length, equals(8));
      expect(BoardPath.starCoordinates.length, equals(4));

      // 4 Starts
      expect(BoardPath.isSafe(const BoardCoordinate(6, 1)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(1, 8)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(8, 13)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(13, 6)), isTrue);

      // 4 Stars
      expect(BoardPath.isSafe(const BoardCoordinate(2, 6)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(6, 12)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(12, 8)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(8, 2)), isTrue);

      // Ordinary track cell is NOT safe
      expect(BoardPath.isSafe(const BoardCoordinate(6, 2)), isFalse);
    });

    test('Home stretch and Home goal coordinates', () {
      // Step 51 enters home stretch
      expect(
        BoardPath.getCoordinate(PlayerColor.red, 51),
        equals(const BoardCoordinate(7, 1)),
      );
      expect(
        BoardPath.getCoordinate(PlayerColor.red, 55),
        equals(const BoardCoordinate(7, 5)),
      );
      // Step 56 is HOME goal
      expect(
        BoardPath.getCoordinate(PlayerColor.red, 56),
        equals(const BoardCoordinate(7, 6)),
      );

      // All home stretch cells are safe
      expect(BoardPath.isSafe(const BoardCoordinate(7, 1)), isTrue);
      expect(BoardPath.isSafe(const BoardCoordinate(7, 6)), isTrue);
    });
  });

  group('Token & Player Models', () {
    test('Token initial state and states transitions', () {
      const token = Token(
        id: 0,
        color: PlayerColor.red,
        stepCount: -1,
        baseSlotIndex: 0,
      );
      expect(token.isInBase, isTrue);
      expect(token.isOnTrack, isFalse);
      expect(token.isHome, isFalse);

      final onTrackToken = token.copyWith(stepCount: 10);
      expect(onTrackToken.isInBase, isFalse);
      expect(onTrackToken.isOnTrack, isTrue);
      expect(onTrackToken.isHome, isFalse);

      final homeToken = token.copyWith(stepCount: 56);
      expect(homeToken.isInBase, isFalse);
      expect(homeToken.isOnTrack, isFalse);
      expect(homeToken.isHome, isTrue);
    });

    test('Player initializes with 4 tokens in base', () {
      final player = Player.initial(PlayerColor.red);
      expect(player.tokens.length, equals(4));
      expect(player.baseCount, equals(4));
      expect(player.trackCount, equals(0));
      expect(player.homeCount, equals(0));
      expect(player.allHome, isFalse);
      expect(player.hasWon, isFalse);
    });
  });
}
