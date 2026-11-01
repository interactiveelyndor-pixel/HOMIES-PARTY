import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/player_color.dart';
import 'snl_config.dart';
import 'snl_game_state.dart';
import 'snl_player.dart';

/// Snakes & Ladders game controller.
///
/// Rules implemented:
/// - Roll dice to get 1–6.
/// - Exactly ONE dice roll per turn for every player (no bonus on 6).
/// - Token starts off-board (position 0) and enters at the rolled number on first move.
/// - Exact roll needed to reach 100 — overshooting leaves the token in place and passes turn.
/// - Landing on a snake head slides down to the snake tail, then passes turn.
/// - Landing on a ladder bottom climbs up to the ladder top, then passes turn.
/// - First player to reach cell 100 wins.
/// - Turn strictly advances in sequential order: Player 1 → Player 2 → Player 3 → Player 4.
/// - Only the current player can roll; all input is locked during animations.
class SnlController extends ChangeNotifier {
  late SnlGameState _state;
  final Random _random;
  final bool enableDelays;
  final Duration rollDuration;
  final Duration stepDuration;
  final Duration slideDelay;
  final Duration autoSkipDuration;

  bool _isProcessingAction = false;
  int _actionSequence = 0;

  SnlController({
    int playerCount = 4,
    List<PlayerColor>? customColors,
    Random? random,
    this.enableDelays = true,
    this.rollDuration = const Duration(milliseconds: 280),
    this.stepDuration = const Duration(milliseconds: 90),
    this.slideDelay = const Duration(milliseconds: 350),
    this.autoSkipDuration = const Duration(milliseconds: 700),
  }) : _random = random ?? Random() {
    initGame(playerCount: playerCount, customColors: customColors);
  }

  SnlGameState get state => _state;
  bool get isProcessingAction => _isProcessingAction;

  /// Initialises a new game.
  /// 2 players: Red & Yellow.
  /// 3 players: Red, Green, Yellow.
  /// 4 players: Red, Green, Yellow, Blue.
  void initGame({int playerCount = 4, List<PlayerColor>? customColors}) {
    final List<PlayerColor> colors;
    if (customColors != null && customColors.isNotEmpty) {
      colors = customColors;
    } else {
      switch (playerCount) {
        case 2:
          colors = [PlayerColor.red, PlayerColor.yellow];
          break;
        case 3:
          colors = [PlayerColor.red, PlayerColor.green, PlayerColor.yellow];
          break;
        default:
          colors = [
            PlayerColor.red,
            PlayerColor.green,
            PlayerColor.yellow,
            PlayerColor.blue,
          ];
      }
    }

    final players = colors.map(SnlPlayer.initial).toList();
    _actionSequence++;
    _isProcessingAction = false;

    _state = SnlGameState(
      players: players,
      currentPlayerIndex: 0,
      phase: SnlTurnPhase.waitingForRoll,
      message: "${players[0].name}'s turn. Roll the dice!",
      actionSequenceId: _actionSequence,
    );

    notifyListeners();
  }

  /// For deterministic testing only.
  @visibleForTesting
  void setStateForTesting(SnlGameState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Rolls the dice. [forcedValue] is for tests.
  Future<void> rollDice({int? forcedValue}) async {
    if (!_state.canRollDice || _isProcessingAction) return;

    _isProcessingAction = true;
    final currentSeq = ++_actionSequence;

    _state = _state.copyWith(
      phase: SnlTurnPhase.rollingDice,
      clearDiceValue: true,
      message: '${_state.currentPlayer.name} is rolling...',
      actionSequenceId: currentSeq,
    );
    notifyListeners();

    if (enableDelays) {
      await Future<void>.delayed(rollDuration);
      if (currentSeq != _actionSequence) return;
    }

    final rolled = forcedValue ?? (_random.nextInt(6) + 1);

    // Update dice display, then animate the move
    _state = _state.copyWith(
      diceValue: rolled,
      phase: SnlTurnPhase.animatingMove,
      message: '${_state.currentPlayer.name} rolled a $rolled! Moving...',
      actionSequenceId: currentSeq,
    );
    notifyListeners();

    await _executeMove(rolled, currentSeq);
  }

  /// Executes the token movement after a dice roll.
  Future<void> _executeMove(int rolled, int currentSeq) async {
    final playerIndex = _state.currentPlayerIndex;
    final player = _state.players[playerIndex];
    final currentPos = player.position;

    // Calculate raw target
    final rawTarget = currentPos + rolled;

    // Overshoot check: if rawTarget > 100, stay in place
    if (rawTarget > 100) {
      _state = _state.copyWith(
        phase: SnlTurnPhase.animatingMove, // Remain animating so roll button is locked
        message: 'Rolled ${_state.diceValue}. Overshoot! Need exact roll to reach 100.',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays) {
        await Future<void>.delayed(autoSkipDuration);
        if (currentSeq != _actionSequence) return;
      }

      _advanceToNextPlayer();
      _isProcessingAction = false;
      return;
    }

    // Animate step-by-step from currentPos to rawTarget
    for (int pos = currentPos + 1; pos <= rawTarget; pos++) {
      final updatedPlayers = List<SnlPlayer>.from(_state.players);
      updatedPlayers[playerIndex] = player.copyWith(position: pos);
      _state = _state.copyWith(
        players: updatedPlayers,
        phase: SnlTurnPhase.animatingMove,
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays) {
        await Future<void>.delayed(stepDuration);
        if (currentSeq != _actionSequence) return;
      }
    }

    // Resolve landing: snake, ladder, win, or plain cell
    await _resolveLanding(playerIndex, rawTarget, currentSeq);
  }

  Future<void> _resolveLanding(
    int playerIndex,
    int landedCell,
    int currentSeq,
  ) async {
    if (landedCell == 100) {
      // Player reached cell 100 and wins!
      final updatedPlayers = List<SnlPlayer>.from(_state.players);
      updatedPlayers[playerIndex] =
          updatedPlayers[playerIndex].copyWith(hasWon: true, position: 100);

      _state = _state.copyWith(
        players: updatedPlayers,
        winner: updatedPlayers[playerIndex],
        phase: SnlTurnPhase.gameWon,
        message:
            '🎉 ${updatedPlayers[playerIndex].name} reached 100 and wins! 🎉',
        actionSequenceId: currentSeq,
      );
      _isProcessingAction = false;
      notifyListeners();
      return;
    }

    // Check for snake
    final snakeTail = SnlConfig.snakeTail(landedCell);
    if (snakeTail != null) {
      _state = _state.copyWith(
        phase: SnlTurnPhase.animatingSnake,
        message: '🐍 Snake! Sliding down from $landedCell to $snakeTail...',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays) {
        await Future<void>.delayed(slideDelay);
        if (currentSeq != _actionSequence) return;
      }

      final updatedPlayers = List<SnlPlayer>.from(_state.players);
      updatedPlayers[playerIndex] =
          updatedPlayers[playerIndex].copyWith(position: snakeTail);
      _state = _state.copyWith(
        players: updatedPlayers,
        phase: SnlTurnPhase.animatingSnake, // Remain animating until turn passes
        message:
            '🐍 Snake! Slid down to $snakeTail.',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (currentSeq != _actionSequence) return;
      }

      _advanceToNextPlayer();
      _isProcessingAction = false;
      return;
    }

    // Check for ladder
    final ladderTop = SnlConfig.ladderTop(landedCell);
    if (ladderTop != null) {
      _state = _state.copyWith(
        phase: SnlTurnPhase.animatingLadder,
        message: '🪜 Ladder! Climbing up from $landedCell to $ladderTop...',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays) {
        await Future<void>.delayed(slideDelay);
        if (currentSeq != _actionSequence) return;
      }

      final updatedPlayers = List<SnlPlayer>.from(_state.players);
      updatedPlayers[playerIndex] =
          updatedPlayers[playerIndex].copyWith(position: ladderTop);
      _state = _state.copyWith(
        players: updatedPlayers,
        phase: SnlTurnPhase.animatingLadder, // Remain animating until turn passes
        message: '🪜 Climbed ladder to $ladderTop!',
        actionSequenceId: currentSeq,
      );
      notifyListeners();

      if (enableDelays) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (currentSeq != _actionSequence) return;
      }

      _advanceToNextPlayer();
      _isProcessingAction = false;
      return;
    }

    // Normal landing on cell without snake or ladder
    if (enableDelays) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (currentSeq != _actionSequence) return;
    }

    // Turn passes deterministically to next player
    _advanceToNextPlayer();
    _isProcessingAction = false;
  }

  /// Advances turn strictly in sequence: Player 0 → 1 → 2 → 3 → 0.
  void _advanceToNextPlayer() {
    final nextIndex =
        (_state.currentPlayerIndex + 1) % _state.players.length;
    final nextPlayer = _state.players[nextIndex];

    _state = _state.copyWith(
      currentPlayerIndex: nextIndex,
      clearDiceValue: true,
      phase: SnlTurnPhase.waitingForRoll,
      message: "${nextPlayer.name}'s turn. Roll the dice!",
      actionSequenceId: _actionSequence,
    );
    notifyListeners();
  }
}
