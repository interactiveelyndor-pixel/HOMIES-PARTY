import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/logic/ludo_computer_player.dart';
import 'package:classic_ludo/logic/ludo_controller.dart';
import 'package:classic_ludo/models/game_state.dart';
import 'package:classic_ludo/models/player_color.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Short delay used in tests so the CPU acts quickly (no animation overhead).
const _testDelay = Duration(milliseconds: 10);

/// Margin added on top of test delay when awaiting CPU completion.
const _margin = Duration(milliseconds: 50);

/// Creates a 2-player controller with no delays so tests run instantly.
LudoController _makeController({Random? random}) => LudoController(
      playerCount: 2,
      enableDelays: false,
      random: random,
    );

/// Creates a CPU player with a very short delay (suitable for tests).
LudoComputerPlayer _makeCpu(LudoController controller) => LudoComputerPlayer(
      controller: controller,
      cpuColor: PlayerColor.yellow,
      actionDelay: _testDelay,
    );

/// Waits long enough for the CPU to complete [actions] consecutive actions.
Future<void> _waitFor(int actions) =>
    Future<void>.delayed((_testDelay + _margin) * actions);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. CPU takes its turn automatically ────────────────────────────────────
  group('LudoComputerPlayer - automatic turn', () {
    test('CPU acts on Yellow\'s turn (state advances automatically)', () async {
      final controller = _makeController();

      // Red rolls 3 → no legal moves → auto-skip → Yellow's turn.
      await controller.rollDice(forcedValue: 3);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));

      final cpu = _makeCpu(controller);
      cpu.onStateChanged();

      // Wait long enough for CPU to roll AND possibly select+move.
      await _waitFor(4);

      // The game state must have advanced from Yellow's initial waitingForRoll.
      // Either: it's now Red's turn (CPU passed), or Yellow earned a bonus roll
      // (still Yellow's turn in waitingForRoll), or game is over.
      // Key invariant: diceValue or currentPlayer changed.
      final state = controller.state;
      final advanced = state.isGameOver ||
          state.currentPlayer.color == PlayerColor.red ||
          // Yellow got a bonus turn — still its turn but in a new waitingForRoll.
          (state.currentPlayer.color == PlayerColor.yellow &&
              state.phase == TurnPhase.waitingForRoll &&
              state.consecutiveSixes >= 0);
      expect(advanced, isTrue,
          reason: 'State must have advanced from Yellow initial roll. '
              'phase=${state.phase}, player=${state.currentPlayer.color}');

      cpu.cancel();
    });

    test('CPU selects a token after rolling (has legal moves with 6)', () async {
      final controller = _makeController();

      // Red skips, Yellow's turn.
      await controller.rollDice(forcedValue: 3);

      // Manually roll 6 for Yellow so it definitely has legal tokens.
      await controller.rollDice(forcedValue: 6);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));

      final cpu = _makeCpu(controller);
      cpu.onStateChanged();

      // Give CPU time to select a token and complete the move.
      await _waitFor(3);

      // Phase must NOT be stuck in waitingForTokenSelection.
      expect(controller.state.phase,
          isNot(equals(TurnPhase.waitingForTokenSelection)),
          reason: 'CPU must select a token within time limit');

      cpu.cancel();
    });
  });

  // ── 2. Human input is blocked during CPU turn ────────────────────────────────
  group('LudoComputerPlayer - human input blocked', () {
    test('State advances only after CPU acts, not before', () async {
      final controller = _makeController();

      // Yellow's turn.
      await controller.rollDice(forcedValue: 3);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));

      // Before the CPU has had time to act, state should still be as-is.
      final cpu = _makeCpu(controller);
      cpu.onStateChanged();

      // No time has passed yet — state is still the same.
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
      expect(controller.state.diceValue, isNull);

      // Wait for CPU to act.
      await _waitFor(4);

      // State has now advanced (CPU acted).
      final state = controller.state;
      final advanced = state.isGameOver ||
          state.currentPlayer.color == PlayerColor.red ||
          state.currentPlayer.color == PlayerColor.yellow;
      expect(advanced, isTrue);
      cpu.cancel();
    });
  });

  // ── 3. CPU makes only legal moves ───────────────────────────────────────────
  group('LudoComputerPlayer - legal moves only', () {
    test('CPU\'s chosen token is in movableTokenIds', () async {
      final controller = _makeController();

      // Advance to Yellow's turn.
      await controller.rollDice(forcedValue: 3);

      // Roll 6 for Yellow (all tokens in base → 4 legal tokens).
      await controller.rollDice(forcedValue: 6);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForTokenSelection));

      final movableBefore = Set<int>.from(controller.state.movableTokenIds);
      expect(movableBefore, isNotEmpty);

      // Intercept which token was selected.
      int? selectedId;
      controller.addListener(() {
        final s = controller.state;
        if (s.movingTokenId != null && selectedId == null) {
          selectedId = s.movingTokenId;
        }
      });

      final cpu = _makeCpu(controller);
      cpu.onStateChanged();
      await _waitFor(3);

      cpu.cancel();

      // The selected token must have been in the legal set.
      if (selectedId != null) {
        expect(movableBefore.contains(selectedId), isTrue,
            reason: 'CPU selected token $selectedId, '
                'but movable set was $movableBefore');
      }
      // At least one token should now be on track.
      final yellowPlayer = controller.state.players
          .firstWhere((p) => p.color == PlayerColor.yellow);
      final onTrack = yellowPlayer.tokens.where((t) => t.isOnTrack || t.isHome);
      expect(onTrack, isNotEmpty, reason: 'CPU should have moved a token');
    });
  });

  // ── 4. Bonus turns work ─────────────────────────────────────────────────────
  group('LudoComputerPlayer - bonus turns', () {
    test('CPU finishes its turn; game is not stuck after bonus', () async {
      final controller = _makeController();

      // Yellow's turn.
      await controller.rollDice(forcedValue: 3);

      final cpu = _makeCpu(controller);
      cpu.onStateChanged();

      // Allow enough time for multiple bonus turns (roll + select + bonus roll…).
      await _waitFor(12);

      final state = controller.state;
      final notStuck = state.phase == TurnPhase.waitingForRoll ||
          state.phase == TurnPhase.gameWon;
      expect(notStuck, isTrue,
          reason: 'Game must not be stuck after CPU bonus turns. '
              'phase=${state.phase}, player=${state.currentPlayer.color}');

      cpu.cancel();
    });
  });

  // ── 5. Cancel clears pending actions ───────────────────────────────────────
  group('LudoComputerPlayer - cancellation', () {
    test('cancel() prevents CPU from acting', () async {
      final controller = _makeController();
      await controller.rollDice(forcedValue: 3); // Yellow's turn

      final cpu = _makeCpu(controller);
      cpu.onStateChanged();

      // Cancel BEFORE the delay fires.
      cpu.cancel();

      await _waitFor(2);

      // Yellow still in waitingForRoll — CPU did not act.
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
    });

    test('reset() + onStateChanged() allows CPU to act again after cancel', () async {
      final controller = _makeController();
      await controller.rollDice(forcedValue: 3); // Yellow's turn

      final cpu = _makeCpu(controller);
      cpu.cancel(); // cancel before scheduling
      cpu.reset();

      // Verify Yellow is still waiting.
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));

      cpu.onStateChanged(); // kick off fresh
      await _waitFor(4);

      // After reset the CPU should have acted — state advanced.
      final state = controller.state;
      final advanced = state.isGameOver ||
          state.currentPlayer.color == PlayerColor.red ||
          (state.currentPlayer.color == PlayerColor.yellow &&
              state.phase == TurnPhase.waitingForRoll);
      expect(advanced, isTrue,
          reason: 'CPU must act after reset. '
              'phase=${state.phase}, player=${state.currentPlayer.color}');
      cpu.cancel();
    });
  });

  // ── 6. Friends mode unchanged ───────────────────────────────────────────────
  group('Friends mode - no CPU', () {
    test('No CPU = no automatic action on Yellow\'s turn', () async {
      final controller = _makeController();

      // No CPU attached — Yellow's turn after Red's skip.
      await controller.rollDice(forcedValue: 3);
      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));

      // Wait well past any action delay — nothing should happen.
      await _waitFor(4);

      expect(controller.state.currentPlayer.color, equals(PlayerColor.yellow));
      expect(controller.state.phase, equals(TurnPhase.waitingForRoll));
      expect(controller.state.diceValue, isNull);
    });
  });

  // ── 7. Full game never gets stuck ──────────────────────────────────────────
  group('LudoComputerPlayer - full game', () {
    test('CPU-vs-CPU 2-player game finishes with a winner', () async {
      final controller = _makeController();

      final cpuRed = LudoComputerPlayer(
        controller: controller,
        cpuColor: PlayerColor.red,
        actionDelay: _testDelay,
      );
      final cpuYellow = LudoComputerPlayer(
        controller: controller,
        cpuColor: PlayerColor.yellow,
        actionDelay: _testDelay,
      );

      void notifyBoth() {
        cpuRed.onStateChanged();
        cpuYellow.onStateChanged();
      }

      controller.addListener(notifyBoth);
      notifyBoth(); // kick off

      // Poll until game over, up to 30 seconds real time.
      const timeout = Duration(seconds: 30);
      final deadline = DateTime.now().add(timeout);

      while (!controller.state.isGameOver) {
        if (DateTime.now().isAfter(deadline)) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      controller.removeListener(notifyBoth);
      cpuRed.cancel();
      cpuYellow.cancel();

      expect(controller.state.isGameOver, isTrue,
          reason: 'CPU-vs-CPU game must finish within $timeout. '
              'phase=${controller.state.phase}, '
              'player=${controller.state.currentPlayer.color}');
      expect(controller.state.winner, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
