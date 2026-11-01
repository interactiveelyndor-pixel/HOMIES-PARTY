import 'carrom_config.dart';
import 'carrom_vec2.dart';

/// Type of Carrom piece.
enum CoinType {
  white,
  black,
  queen,
  striker,
}

/// Identifiers for the two local players.
enum CarromPlayerId {
  player1,
  player2,
}

extension CarromPlayerIdExtension on CarromPlayerId {
  CarromPlayerId get opponent =>
      this == CarromPlayerId.player1 ? CarromPlayerId.player2 : CarromPlayerId.player1;

  CoinType get targetCoinType =>
      this == CarromPlayerId.player1 ? CoinType.white : CoinType.black;

  String get displayName =>
      this == CarromPlayerId.player1 ? 'White' : 'Black';

  double get baselineY =>
      this == CarromPlayerId.player1
          ? CarromConfig.player1BaselineY
          : CarromConfig.player2BaselineY;
}

/// Tracking status of the red Queen.
enum QueenStatus {
  /// Queen is on the active board.
  onBoard,

  /// Queen was pocketed by a player, who must now cover it by pocketing their own coin.
  pendingCover,

  /// Queen was successfully covered and awarded to the covering player.
  covered,
}

/// Turn state machine phases.
enum CarromTurnPhase {
  /// Current player is positioning the striker along their baseline.
  positioningStriker,

  /// Current player is dragging back to aim and build power.
  aiming,

  /// Striker was released; physics engine is calculating motion; input is strictly locked.
  simulating,

  /// Game has ended with a winner.
  gameOver,
}

/// Represents a physical coin or striker on the Carrom board.
class CarromCoin {
  final int id;
  final CoinType type;
  CarromVec2 position;
  CarromVec2 velocity;
  final double radius;
  final double mass;
  bool isPocketed;

  CarromCoin({
    required this.id,
    required this.type,
    required this.position,
    CarromVec2? velocity,
    double? radius,
    double? mass,
    this.isPocketed = false,
  })  : velocity = velocity ?? CarromVec2.zero,
        radius = radius ??
            (type == CoinType.striker
                ? CarromConfig.strikerRadius
                : CarromConfig.coinRadius),
        mass = mass ??
            (type == CoinType.striker
                ? CarromConfig.strikerMass
                : CarromConfig.coinMass);

  bool get isStriker => type == CoinType.striker;
  bool get isQueen => type == CoinType.queen;
  bool get isWhite => type == CoinType.white;
  bool get isBlack => type == CoinType.black;

  CarromCoin clone() => CarromCoin(
        id: id,
        type: type,
        position: position,
        velocity: velocity,
        radius: radius,
        mass: mass,
        isPocketed: isPocketed,
      );
}

/// Player state tracking.
class CarromPlayer {
  final CarromPlayerId id;
  final String name;
  final CoinType assignedCoin;
  int whiteCoinsPocketed;
  int blackCoinsPocketed;
  bool hasCoveredQueen;

  CarromPlayer({
    required this.id,
    required this.name,
    required this.assignedCoin,
    int? pocketedCount,
    this.whiteCoinsPocketed = 0,
    this.blackCoinsPocketed = 0,
    this.hasCoveredQueen = false,
  }) {
    if (pocketedCount != null && whiteCoinsPocketed == 0 && blackCoinsPocketed == 0) {
      if (assignedCoin == CoinType.white) {
        whiteCoinsPocketed = pocketedCount;
      } else {
        blackCoinsPocketed = pocketedCount;
      }
    }
  }

  int get pocketedCount => whiteCoinsPocketed + blackCoinsPocketed;

  set pocketedCount(int value) {
    if (assignedCoin == CoinType.white) {
      whiteCoinsPocketed = value;
      blackCoinsPocketed = 0;
    } else {
      blackCoinsPocketed = value;
      whiteCoinsPocketed = 0;
    }
  }

  /// Total points earned based on pocketed coins:
  /// Black = 10 pts, White = 20 pts, Queen = 50 pts (if covered).
  int get score =>
      (whiteCoinsPocketed * CarromConfig.whiteCoinPoints) +
      (blackCoinsPocketed * CarromConfig.blackCoinPoints) +
      (hasCoveredQueen ? CarromConfig.queenPoints : 0);

  CarromPlayer clone() => CarromPlayer(
        id: id,
        name: name,
        assignedCoin: assignedCoin,
        whiteCoinsPocketed: whiteCoinsPocketed,
        blackCoinsPocketed: blackCoinsPocketed,
        hasCoveredQueen: hasCoveredQueen,
      );
}
