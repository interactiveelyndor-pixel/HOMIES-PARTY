import 'package:flutter/foundation.dart';
import 'snl_player.dart';

enum SnlTurnPhase {
  waitingForRoll,
  rollingDice,
  animatingMove,  // moving token step-by-step
  animatingSnake, // sliding down a snake
  animatingLadder, // climbing a ladder
  gameWon,
}

/// Immutable Snakes & Ladders game state.
@immutable
class SnlGameState {
  final List<SnlPlayer> players;
  final int currentPlayerIndex;
  final int? diceValue;
  final SnlTurnPhase phase;
  final SnlPlayer? winner;
  final String message;
  final int actionSequenceId;

  const SnlGameState({
    required this.players,
    required this.currentPlayerIndex,
    this.diceValue,
    required this.phase,
    this.winner,
    required this.message,
    this.actionSequenceId = 0,
  });

  SnlPlayer get currentPlayer => players[currentPlayerIndex];

  bool get isGameOver => winner != null || phase == SnlTurnPhase.gameWon;

  bool get canRollDice =>
      phase == SnlTurnPhase.waitingForRoll && !isGameOver;

  bool get isAnimating =>
      phase == SnlTurnPhase.rollingDice ||
      phase == SnlTurnPhase.animatingMove ||
      phase == SnlTurnPhase.animatingSnake ||
      phase == SnlTurnPhase.animatingLadder;

  SnlGameState copyWith({
    List<SnlPlayer>? players,
    int? currentPlayerIndex,
    int? diceValue,
    bool clearDiceValue = false,
    SnlTurnPhase? phase,
    SnlPlayer? winner,
    String? message,
    int? actionSequenceId,
  }) {
    return SnlGameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      phase: phase ?? this.phase,
      winner: winner ?? this.winner,
      message: message ?? this.message,
      actionSequenceId: actionSequenceId ?? this.actionSequenceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnlGameState &&
          runtimeType == other.runtimeType &&
          listEquals(players, other.players) &&
          currentPlayerIndex == other.currentPlayerIndex &&
          diceValue == other.diceValue &&
          phase == other.phase &&
          winner == other.winner &&
          message == other.message &&
          actionSequenceId == other.actionSequenceId;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(players),
        currentPlayerIndex,
        diceValue,
        phase,
        winner,
        message,
        actionSequenceId,
      );
}
