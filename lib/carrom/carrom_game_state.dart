import 'carrom_models.dart';
import 'carrom_vec2.dart';

/// Immutable snapshot of the entire Carrom game state.
class CarromGameState {
  final List<CarromCoin> coins;
  final CarromCoin striker;
  final CarromPlayer player1;
  final CarromPlayer player2;
  final CarromPlayerId currentTurn;
  final CarromTurnPhase phase;
  final QueenStatus queenStatus;
  final CarromPlayerId? queenPocketedBy;
  final CarromPlayerId? winner;
  final String statusMessage;
  final double strikerX;
  final CarromVec2? dragAimVector;
  final double aimPower; // 0.0 to 1.0

  const CarromGameState({
    required this.coins,
    required this.striker,
    required this.player1,
    required this.player2,
    required this.currentTurn,
    required this.phase,
    required this.queenStatus,
    this.queenPocketedBy,
    this.winner,
    required this.statusMessage,
    required this.strikerX,
    this.dragAimVector,
    this.aimPower = 0.0,
  });

  CarromPlayer get currentPlayer =>
      currentTurn == CarromPlayerId.player1 ? player1 : player2;

  CarromPlayer get opponentPlayer =>
      currentTurn == CarromPlayerId.player1 ? player2 : player1;

  double get currentBaselineY => currentTurn.baselineY;

  int get whiteCoinsRemaining =>
      coins.where((c) => c.isWhite && !c.isPocketed).length;

  int get blackCoinsRemaining =>
      coins.where((c) => c.isBlack && !c.isPocketed).length;

  bool get isQueenOnBoard =>
      coins.any((c) => c.isQueen && !c.isPocketed);

  CarromGameState copyWith({
    List<CarromCoin>? coins,
    CarromCoin? striker,
    CarromPlayer? player1,
    CarromPlayer? player2,
    CarromPlayerId? currentTurn,
    CarromTurnPhase? phase,
    QueenStatus? queenStatus,
    CarromPlayerId? Function()? queenPocketedBy,
    CarromPlayerId? Function()? winner,
    String? statusMessage,
    double? strikerX,
    CarromVec2? Function()? dragAimVector,
    double? aimPower,
  }) {
    return CarromGameState(
      coins: coins ?? this.coins,
      striker: striker ?? this.striker,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      currentTurn: currentTurn ?? this.currentTurn,
      phase: phase ?? this.phase,
      queenStatus: queenStatus ?? this.queenStatus,
      queenPocketedBy:
          queenPocketedBy != null ? queenPocketedBy() : this.queenPocketedBy,
      winner: winner != null ? winner() : this.winner,
      statusMessage: statusMessage ?? this.statusMessage,
      strikerX: strikerX ?? this.strikerX,
      dragAimVector:
          dragAimVector != null ? dragAimVector() : this.dragAimVector,
      aimPower: aimPower ?? this.aimPower,
    );
  }
}
