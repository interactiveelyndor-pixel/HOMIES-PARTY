import 'package:flutter/foundation.dart';
import 'player.dart';

enum TurnPhase {
  waitingForRoll,
  rollingDice,
  waitingForTokenSelection,
  animatingMove,
  gameWon,
}

@immutable
class GameState {
  final List<Player> players;
  final int currentPlayerIndex;
  final int? diceValue;
  final TurnPhase phase;
  final int consecutiveSixes;
  final Set<int> movableTokenIds;
  final int? movingTokenId;
  final Player? winner;
  final String message;
  final int actionSequenceId;

  const GameState({
    required this.players,
    required this.currentPlayerIndex,
    this.diceValue,
    required this.phase,
    this.consecutiveSixes = 0,
    this.movableTokenIds = const {},
    this.movingTokenId,
    this.winner,
    required this.message,
    this.actionSequenceId = 0,
  });

  Player get currentPlayer => players[currentPlayerIndex];

  bool get isGameOver => winner != null || phase == TurnPhase.gameWon;

  bool get canRollDice =>
      phase == TurnPhase.waitingForRoll && !isGameOver;

  bool get canSelectToken =>
      phase == TurnPhase.waitingForTokenSelection && !isGameOver;

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? diceValue,
    bool clearDiceValue = false,
    TurnPhase? phase,
    int? consecutiveSixes,
    Set<int>? movableTokenIds,
    int? movingTokenId,
    bool clearMovingToken = false,
    Player? winner,
    String? message,
    int? actionSequenceId,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      phase: phase ?? this.phase,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      movableTokenIds: movableTokenIds ?? this.movableTokenIds,
      movingTokenId:
          clearMovingToken ? null : (movingTokenId ?? this.movingTokenId),
      winner: winner ?? this.winner,
      message: message ?? this.message,
      actionSequenceId: actionSequenceId ?? this.actionSequenceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          listEquals(players, other.players) &&
          currentPlayerIndex == other.currentPlayerIndex &&
          diceValue == other.diceValue &&
          phase == other.phase &&
          consecutiveSixes == other.consecutiveSixes &&
          setEquals(movableTokenIds, other.movableTokenIds) &&
          movingTokenId == other.movingTokenId &&
          winner == other.winner &&
          message == other.message &&
          actionSequenceId == other.actionSequenceId;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(players),
        currentPlayerIndex,
        diceValue,
        phase,
        consecutiveSixes,
        Object.hashAll(movableTokenIds),
        movingTokenId,
        winner,
        message,
        actionSequenceId,
      );
}
