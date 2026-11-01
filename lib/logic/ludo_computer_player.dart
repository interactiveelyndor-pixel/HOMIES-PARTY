import 'dart:async';
import '../models/board_coordinate.dart';
import '../models/board_path.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/player_color.dart';
import '../models/token.dart';
import 'ludo_controller.dart';

/// Drives the computer player (Yellow, index 1 in a 2-player game) automatically.
///
/// Design rules:
/// - Calls only [LudoController.rollDice] and [LudoController.selectToken] —
///   the same public API a human uses.
/// - Reuses [LudoController.getLegalMoves] for legality checks.
/// - Never modifies game state directly.
/// - Cancels all pending work when [cancel] is called (screen dispose /
///   game restart / game won).
/// - Guards against double-scheduling with [_scheduled].
class LudoComputerPlayer {
  final LudoController controller;
  final PlayerColor cpuColor;

  /// Short pause before each CPU action so the human can see what happened.
  /// Defaults to 600 ms; tests may pass a shorter value.
  final Duration actionDelay;

  bool _cancelled = false;
  bool _scheduled = false;
  Timer? _actionTimer;

  LudoComputerPlayer({
    required this.controller,
    required this.cpuColor,
    this.actionDelay = const Duration(milliseconds: 600),
  });

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Notify the CPU that game state changed.  Should be called from the
  /// controller's listener in the screen state.
  void onStateChanged() {
    if (_cancelled) return;
    final state = controller.state;

    // Nothing to do once the game is over.
    if (state.isGameOver) return;

    // Only act on the CPU's turn.
    if (state.currentPlayer.color != cpuColor) return;

    // Don't schedule a second action while one is already pending.
    if (_scheduled) return;

    // Don't act while the controller is busy with an animation / transition.
    if (controller.isProcessingAction) return;

    _scheduleAction(state.phase);
  }

  /// Cancel all pending CPU actions (call on dispose / restart / game end).
  void cancel() {
    _cancelled = true;
    _scheduled = false;
    _actionTimer?.cancel();
    _actionTimer = null;
  }

  /// Reset state so the CPU can act on a fresh game.
  void reset() {
    _cancelled = false;
    _scheduled = false;
    _actionTimer?.cancel();
    _actionTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Internal scheduling
  // ---------------------------------------------------------------------------

  void _scheduleAction(TurnPhase phase) {
    if (_cancelled || _scheduled) return;

    if (phase == TurnPhase.waitingForRoll ||
        phase == TurnPhase.waitingForTokenSelection) {
      _scheduled = true;
      _actionTimer?.cancel();
      _actionTimer = Timer(actionDelay, () {
        _actionTimer = null;
        _executeAction();
      });
    }
  }

  Future<void> _executeAction() async {
    _scheduled = false;
    if (_cancelled) return;

    final state = controller.state;
    if (state.isGameOver) return;
    if (state.currentPlayer.color != cpuColor) return;
    if (controller.isProcessingAction) {
      // Still busy — try again shortly.
      _scheduleAction(state.phase);
      return;
    }

    if (state.phase == TurnPhase.waitingForRoll) {
      await controller.rollDice();
      onStateChanged();
    } else if (state.phase == TurnPhase.waitingForTokenSelection) {
      final tokenId = _chooseToken(state);
      if (tokenId != null) {
        await controller.selectToken(tokenId);
        onStateChanged();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Token selection heuristic
  // ---------------------------------------------------------------------------

  /// Picks the best token to move given the current [state].
  ///
  /// Priority (deterministic, no randomness):
  /// 1. Move a token into HOME (stepCount reaches 56).
  /// 2. Capture an opponent token on a non-safe cell.
  /// 3. Bring a token out of base with a 6.
  /// 4. Move to a safe cell or out of danger.
  /// 5. Advance the furthest token on the track.
  ///
  /// If exactly one legal token exists the method still uses the heuristic
  /// (consistent with the existing auto-select in the screen for humans).
  int? _chooseToken(GameState state) {
    final player = state.currentPlayer;
    final dice = state.diceValue;
    if (dice == null) return null;

    final movable = controller.getLegalMoves(player, dice);
    if (movable.isEmpty) return null;

    // Candidate tokens (only movable ones).
    final candidates =
        player.tokens.where((t) => movable.contains(t.id)).toList();

    // Exactly one legal token: move it.
    if (candidates.length == 1) return candidates.first.id;

    // ── Priority 1: reach HOME ────────────────────────────────────────────────
    for (final t in candidates) {
      if (t.isOnTrack && t.stepCount + dice == BoardPath.totalStepsToHome) {
        return t.id;
      }
    }

    // ── Priority 2: capture an opponent ──────────────────────────────────────
    final opponents =
        state.players.where((p) => p.color != cpuColor).toList();
    for (final t in candidates) {
      if (!t.isOnTrack || t.isInBase) continue;
      final targetStep = t.stepCount + dice;
      if (targetStep > BoardPath.totalStepsToHome) continue;
      final targetCoord = BoardPath.getCoordinate(cpuColor, targetStep);
      if (BoardPath.isSafe(targetCoord)) continue;

      if (_hasOpponentAt(opponents, targetCoord)) {
        return t.id;
      }
    }

    // ── Priority 3: bring a token out of base (dice == 6) ────────────────────
    if (dice == 6) {
      for (final t in candidates) {
        if (t.isInBase) return t.id;
      }
    }

    // ── Priority 4: move to a safe cell or out of danger ─────────────────────
    for (final t in candidates) {
      if (!t.isOnTrack) continue;
      final targetStep = t.stepCount + dice;
      if (targetStep > BoardPath.totalStepsToHome) continue;
      final targetCoord = BoardPath.getCoordinate(cpuColor, targetStep);

      if (BoardPath.isSafe(targetCoord)) {
        return t.id;
      }

      // Also prefer moving away from a cell that an opponent threatens.
      if (_isThreatened(t, state, opponents)) {
        return t.id;
      }
    }

    // ── Priority 5: advance the furthest token on track ───────────────────────
    Token? best;
    for (final t in candidates) {
      if (!t.isOnTrack) continue;
      if (best == null || t.stepCount > best.stepCount) {
        best = t;
      }
    }
    if (best != null) return best.id;

    // Fallback: first movable candidate (shouldn't normally reach here).
    return candidates.first.id;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _hasOpponentAt(List<Player> opponents, BoardCoordinate coord) {
    for (final opp in opponents) {
      for (final t in opp.tokens) {
        if (!t.isOnTrack || t.isInHomeStretch) continue;
        final c = BoardPath.getCoordinate(opp.color, t.stepCount);
        if (c == coord) return true;
      }
    }
    return false;
  }

  /// Returns true if any opponent could capture [token] on its current cell.
  bool _isThreatened(
      Token token, GameState state, List<Player> opponents) {
    if (!token.isOnTrack || token.isInHomeStretch) return false;
    final myCoord = BoardPath.getCoordinate(cpuColor, token.stepCount);
    if (BoardPath.isSafe(myCoord)) return false;

    for (final opp in opponents) {
      for (final t in opp.tokens) {
        if (!t.isOnTrack || t.isInHomeStretch) continue;
        // Check if the opponent can reach myCoord with a roll of 1..6.
        for (int roll = 1; roll <= 6; roll++) {
          final targetStep = t.stepCount + roll;
          if (targetStep > BoardPath.totalStepsToHome) continue;
          final c = BoardPath.getCoordinate(opp.color, targetStep);
          if (c == myCoord) return true;
        }
      }
    }
    return false;
  }
}
