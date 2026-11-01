import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/snl/snl_colors.dart';
import 'package:classic_ludo/snl/snl_config.dart';
import 'package:classic_ludo/snl/snl_controller.dart';
import 'package:classic_ludo/snl/snl_game_state.dart';
import 'package:classic_ludo/models/player_color.dart';

void main() {
  group('SnlConfig - Board Configuration', () {
    test('Has exactly 8 snakes and 8 ladders', () {
      expect(SnlConfig.snakes.length, equals(8));
      expect(SnlConfig.ladders.length, equals(8));
    });

    test('No snake or ladder endpoint is cell 1 or 100', () {
      for (final entry in SnlConfig.snakes.entries) {
        expect(entry.key, isNot(equals(1)));
        expect(entry.key, isNot(equals(100)));
        expect(entry.value, isNot(equals(1)));
        expect(entry.value, isNot(equals(100)));
      }
      for (final entry in SnlConfig.ladders.entries) {
        expect(entry.key, isNot(equals(1)));
        expect(entry.key, isNot(equals(100)));
        expect(entry.value, isNot(equals(1)));
        expect(entry.value, isNot(equals(100)));
      }
    });

    test('Snake heads > snake tails (snake goes down)', () {
      for (final entry in SnlConfig.snakes.entries) {
        expect(entry.key, greaterThan(entry.value));
      }
    });

    test('Ladder bottoms < ladder tops (ladder goes up)', () {
      for (final entry in SnlConfig.ladders.entries) {
        expect(entry.key, lessThan(entry.value));
      }
    });

    test('No ladder top coincides with a snake head', () {
      final snakeHeads = SnlConfig.snakes.keys.toSet();
      for (final top in SnlConfig.ladders.values) {
        expect(snakeHeads.contains(top), isFalse,
            reason: 'Ladder top $top must not be a snake head');
      }
    });

    test('No overlap between snake heads and ladder bottoms', () {
      final snakeHeads = SnlConfig.snakes.keys.toSet();
      final ladderBottoms = SnlConfig.ladders.keys.toSet();
      final overlap = snakeHeads.intersection(ladderBottoms);
      expect(overlap, isEmpty);
    });
  });

  group('SnlController - Player Modes & Identity Consistency', () {
    test('Initializes 2-player game with Red and Yellow', () {
      final c = SnlController(playerCount: 2, enableDelays: false);
      expect(c.state.players.length, equals(2));
      expect(c.state.players[0].color, equals(PlayerColor.red));
      expect(c.state.players[1].color, equals(PlayerColor.yellow));
      expect(c.state.currentPlayerIndex, equals(0));
      expect(c.state.canRollDice, isTrue);
    });

    test('Initializes 3-player game with Red, Green, Yellow', () {
      final c = SnlController(playerCount: 3, enableDelays: false);
      expect(c.state.players.length, equals(3));
      expect(c.state.players[0].color, equals(PlayerColor.red));
      expect(c.state.players[1].color, equals(PlayerColor.green));
      expect(c.state.players[2].color, equals(PlayerColor.yellow));
    });

    test('Initializes 4-player game with all 4 colors', () {
      final c = SnlController(playerCount: 4, enableDelays: false);
      expect(c.state.players.length, equals(4));
      expect(c.state.players[0].color, equals(PlayerColor.red));
      expect(c.state.players[1].color, equals(PlayerColor.green));
      expect(c.state.players[2].color, equals(PlayerColor.yellow));
      expect(c.state.players[3].color, equals(PlayerColor.blue));
    });

    test('All players start at position 0 (off-board)', () {
      final c = SnlController(playerCount: 4, enableDelays: false);
      for (final p in c.state.players) {
        expect(p.position, equals(0));
        expect(p.hasWon, isFalse);
      }
    });

    test('Player name and color match consistently for 2P, 3P, and 4P', () {
      for (final count in [2, 3, 4]) {
        final c = SnlController(playerCount: count, enableDelays: false);
        for (final p in c.state.players) {
          expect(p.name, equals(p.color.displayName));
          expect(p.primaryColor, equals(SnlColors.playerPrimary(p.color)));
          expect(p.darkColor, equals(SnlColors.playerDark(p.color)));
          expect(p.glowColor, equals(SnlColors.playerGlow(p.color)));
        }
        // In 2P mode specifically: Yellow must be Yellow, not green!
        if (count == 2) {
          expect(c.state.players[1].name, equals('Yellow'));
          expect(c.state.players[1].color, equals(PlayerColor.yellow));
          expect(c.state.players[1].primaryColor, equals(SnlColors.yellow));
          expect(c.state.players[1].primaryColor, isNot(equals(SnlColors.green)));
        }
      }
    });
  });

  group('SnlController - Exactly One Roll Per Turn & Sequential Switching', () {
    test('Roll advances player position by rolled amount and passes turn', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      await c.rollDice(forcedValue: 3);
      expect(c.state.players[0].position, equals(3));
      // Turn passed to Yellow
      expect(c.state.currentPlayerIndex, equals(1));
    });

    test('Rolling 6 moves token and passes turn to next player (no extra turn)', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      await c.rollDice(forcedValue: 6);
      // Red moved to 6
      expect(c.state.players[0].position, equals(6));
      // Turn MUST pass to Yellow (player index 1), no extra turn
      expect(c.state.currentPlayerIndex, equals(1));
      expect(c.state.phase, equals(SnlTurnPhase.waitingForRoll));
    });

    test('Every rolled value 1 to 6 gives exactly one roll and passes turn', () async {
      for (int roll = 1; roll <= 6; roll++) {
        final c = SnlController(playerCount: 2, enableDelays: false);
        expect(c.state.currentPlayerIndex, equals(0));
        await c.rollDice(forcedValue: roll);
        // After any roll 1..6, turn MUST pass to next player (index 1)
        expect(c.state.currentPlayerIndex, equals(1),
            reason: 'Roll of $roll should pass turn to Player 1');
      }
    });

    test('Deterministic sequential turn order across full rounds in 4-player game', () async {
      final c = SnlController(playerCount: 4, enableDelays: false);
      // Round 1
      expect(c.state.currentPlayerIndex, equals(0)); // Red
      await c.rollDice(forcedValue: 2);
      expect(c.state.currentPlayerIndex, equals(1)); // Green
      await c.rollDice(forcedValue: 2);
      expect(c.state.currentPlayerIndex, equals(2)); // Yellow
      await c.rollDice(forcedValue: 2);
      expect(c.state.currentPlayerIndex, equals(3)); // Blue
      await c.rollDice(forcedValue: 2);

      // Round 2 back to Red
      expect(c.state.currentPlayerIndex, equals(0)); // Red
      await c.rollDice(forcedValue: 6); // Even on 6!
      expect(c.state.currentPlayerIndex, equals(1)); // Green
    });

    test('Overshooting 100 leaves token in place and passes turn', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      // Place Red at position 98
      final setup = c.state.copyWith(
        players: [
          c.state.players[0].copyWith(position: 98),
          c.state.players[1],
        ],
      );
      c.setStateForTesting(setup);

      // Roll 5 → 98 + 5 = 103 > 100 → overshoot
      await c.rollDice(forcedValue: 5);

      expect(c.state.players[0].position, equals(98)); // unchanged
      expect(c.state.currentPlayerIndex, equals(1)); // passed to Yellow
    });

    test('Exact roll to reach 100 wins the game', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      final setup = c.state.copyWith(
        players: [
          c.state.players[0].copyWith(position: 96),
          c.state.players[1],
        ],
      );
      c.setStateForTesting(setup);

      await c.rollDice(forcedValue: 4); // 96 + 4 = 100 → win!

      expect(c.state.players[0].position, equals(100));
      expect(c.state.players[0].hasWon, isTrue);
      expect(c.state.phase, equals(SnlTurnPhase.gameWon));
      expect(c.state.winner, isNotNull);
      expect(c.state.winner!.color, equals(PlayerColor.red));
    });
  });

  group('SnlController - Snakes & Ladders Movement', () {
    test('Landing on a snake head sends token to snake tail and passes turn', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      // Snake: 17 → 7. Place Red at 14, roll 3 to land on 17.
      final setup = c.state.copyWith(
        players: [
          c.state.players[0].copyWith(position: 14),
          c.state.players[1],
        ],
      );
      c.setStateForTesting(setup);

      await c.rollDice(forcedValue: 3); // 14 + 3 = 17 (snake head)

      expect(c.state.players[0].position, equals(7)); // at snake tail
      expect(c.state.currentPlayerIndex, equals(1)); // turn passes
    });

    test('Landing on a ladder bottom climbs to ladder top and passes turn', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      // Ladder: 4 → 25. Place Red at 1, roll 3 to land on 4.
      final setup = c.state.copyWith(
        players: [
          c.state.players[0].copyWith(position: 1),
          c.state.players[1],
        ],
      );
      c.setStateForTesting(setup);

      await c.rollDice(forcedValue: 3); // 1 + 3 = 4 (ladder bottom)

      expect(c.state.players[0].position, equals(25)); // at ladder top
      expect(c.state.currentPlayerIndex, equals(1)); // turn passes
    });

    test('Landing on a snake on roll of 6 advances turn to next player', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      // Snake: 17 → 7. Place Red at 11, roll 6 to land on 17.
      final setup = c.state.copyWith(
        players: [
          c.state.players[0].copyWith(position: 11),
          c.state.players[1],
        ],
      );
      c.setStateForTesting(setup);

      await c.rollDice(forcedValue: 6); // 11 + 6 = 17 → snake!
      expect(c.state.players[0].position, equals(7));
      expect(c.state.currentPlayerIndex, equals(1)); // Yellow's turn
    });

    test('Landing on a ladder on roll of 6 advances turn to next player', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      // Ladder: 9 → 31. Place Red at 3, roll 6 → lands on 9 → climbs to 31
      final setup = c.state.copyWith(
        players: [
          c.state.players[0].copyWith(position: 3),
          c.state.players[1],
        ],
      );
      c.setStateForTesting(setup);

      await c.rollDice(forcedValue: 6); // 3 + 6 = 9 (ladder bottom)
      expect(c.state.players[0].position, equals(31));
      // No extra turn on 6: turn MUST pass to Yellow (index 1)
      expect(c.state.currentPlayerIndex, equals(1));
    });
  });

  group('SnlController - Input Protection & Reliability', () {
    test('Cannot roll when not in waitingForRoll phase', () async {
      final c = SnlController(playerCount: 2, enableDelays: false);
      c.setStateForTesting(c.state.copyWith(
        phase: SnlTurnPhase.animatingMove,
      ));
      final prevIndex = c.state.currentPlayerIndex;
      await c.rollDice(forcedValue: 3); // should be ignored
      expect(c.state.currentPlayerIndex, equals(prevIndex));
      expect(c.state.phase, equals(SnlTurnPhase.animatingMove));
    });

    test('Rapid double roll is ignored while first roll is processing', () async {
      final c = SnlController(
        playerCount: 2,
        enableDelays: true,
        rollDuration: const Duration(milliseconds: 30),
        stepDuration: const Duration(milliseconds: 10),
      );
      final future1 = c.rollDice(forcedValue: 3);
      final future2 = c.rollDice(forcedValue: 5); // should be a no-op
      await Future.wait([future1, future2]);
      // Red should have moved to 3 (first roll only)
      expect(c.state.players[0].position, equals(3));
      // Turn passed to Yellow
      expect(c.state.currentPlayerIndex, equals(1));
    });
  });
}
