import 'carrom_board_layout.dart';
import 'carrom_config.dart';
import 'carrom_game_state.dart';
import 'carrom_models.dart';
import 'carrom_physics.dart';
import 'carrom_vec2.dart';

/// Pure Dart controller for Carrom.
/// Zero Flutter imports: completely isolated game logic, turn management,
/// physics simulation loop, and rule resolution.
class CarromController {
  CarromGameState _state;
  final List<void Function()> _listeners = [];

  // Simulation accumulator and safety timer
  double _elapsedSimTime = 0.0;
  final List<CarromCoin> _coinsPocketedThisShot = [];
  bool _isProcessingAction = false;
  int _actionSequence = 0;

  CarromController({
    CarromGameState? initialState,
    String player1Name = 'Player 1',
    String player2Name = 'Player 2',
  }) : _state = initialState ?? _createInitialState(
          player1Name: player1Name,
          player2Name: player2Name,
        ) {
    _initStrikerPosition();
  }

  CarromGameState get state => _state;
  bool get isProcessingAction => _isProcessingAction;
  int get actionSequence => _actionSequence;

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  static CarromGameState _createInitialState({
    String player1Name = 'Player 1',
    String player2Name = 'Player 2',
  }) {
    final coins = CarromBoardLayout.createInitialCoins();
    final p1 = CarromPlayer(
      id: CarromPlayerId.player1,
      name: player1Name,
      assignedCoin: CoinType.white,
    );
    final p2 = CarromPlayer(
      id: CarromPlayerId.player2,
      name: player2Name,
      assignedCoin: CoinType.black,
    );

    final initialStrikerX = (CarromConfig.baselineMinX + CarromConfig.baselineMaxX) / 2.0;
    final striker = CarromCoin(
      id: 999,
      type: CoinType.striker,
      position: CarromVec2(initialStrikerX, CarromConfig.player1BaselineY),
      velocity: CarromVec2.zero,
    );

    return CarromGameState(
      coins: coins,
      striker: striker,
      player1: p1,
      player2: p2,
      currentTurn: CarromPlayerId.player1,
      phase: CarromTurnPhase.positioningStriker,
      queenStatus: QueenStatus.onBoard,
      statusMessage: "White's Turn - Position Striker",
      strikerX: initialStrikerX,
    );
  }

  /// Resets the game to a clean, fresh standard starting board.
  void resetGame({
    String player1Name = 'Player 1',
    String player2Name = 'Player 2',
  }) {
    _actionSequence++;
    _isProcessingAction = false;
    _elapsedSimTime = 0.0;
    _coinsPocketedThisShot.clear();
    _state = _createInitialState(
      player1Name: player1Name,
      player2Name: player2Name,
    );
    _initStrikerPosition();
    _notifyListeners();
  }

  /// Sets striker to a safe, valid legal spot along current player's baseline.
  void _initStrikerPosition() {
    final validX = CarromBoardLayout.clampAndFindValidStrikerX(
      _state.strikerX,
      _state.currentBaselineY,
      _state.coins,
    );
    final striker = _state.striker.clone()
      ..position = CarromVec2(validX, _state.currentBaselineY)
      ..velocity = CarromVec2.zero
      ..isPocketed = false;

    _state = _state.copyWith(
      striker: striker,
      strikerX: validX,
      phase: CarromTurnPhase.positioningStriker,
    );
  }

  // --- Input & Player Interaction ---

  /// Adjusts striker position along current player's baseline.
  /// Ignores input if game is over or physics is currently simulating.
  void setStrikerPosition(double desiredX) {
    if (_state.phase != CarromTurnPhase.positioningStriker &&
        _state.phase != CarromTurnPhase.aiming) {
      return;
    }

    final validX = CarromBoardLayout.clampAndFindValidStrikerX(
      desiredX,
      _state.currentBaselineY,
      _state.coins,
    );

    final striker = _state.striker.clone()
      ..position = CarromVec2(validX, _state.currentBaselineY)
      ..velocity = CarromVec2.zero;

    _state = _state.copyWith(
      striker: striker,
      strikerX: validX,
    );
    _notifyListeners();
  }

  /// Begins aiming by dragging backward from the striker.
  void startAiming(CarromVec2 touchPoint) {
    if (_state.phase != CarromTurnPhase.positioningStriker &&
        _state.phase != CarromTurnPhase.aiming) {
      return;
    }

    // Ensure touch is within reasonable proximity of striker or baseline
    _updateAimDrag(touchPoint);
  }

  /// Updates aim drag and calculates power indicator.
  void updateAim(CarromVec2 currentTouchPoint) {
    if (_state.phase != CarromTurnPhase.positioningStriker &&
        _state.phase != CarromTurnPhase.aiming) {
      return;
    }

    _updateAimDrag(currentTouchPoint);
  }

  void _updateAimDrag(CarromVec2 touchPoint) {
    // Aim vector points in opposite direction of drag (slingshot pull-back)
    final dragBackVector = _state.striker.position - touchPoint;
    final dist = dragBackVector.length;

    if (dist < 4.0) {
      _state = _state.copyWith(
        phase: CarromTurnPhase.positioningStriker,
        dragAimVector: () => null,
        aimPower: 0.0,
      );
    } else {
      final clampedDist = dist.clamp(0.0, CarromConfig.maxPullDistance);
      final power = (clampedDist / CarromConfig.maxPullDistance).clamp(0.0, 1.0);
      final aimDir = dragBackVector.normalized();

      _state = _state.copyWith(
        phase: CarromTurnPhase.aiming,
        dragAimVector: () => aimDir * clampedDist,
        aimPower: power,
      );
    }
    _notifyListeners();
  }

  /// Cancels aiming without shooting.
  void cancelAim() {
    if (_state.phase != CarromTurnPhase.aiming) return;
    _state = _state.copyWith(
      phase: CarromTurnPhase.positioningStriker,
      dragAimVector: () => null,
      aimPower: 0.0,
    );
    _notifyListeners();
  }

  /// Releases the shot, transferring impulse velocity to the striker.
  /// Transitions state machine to [CarromTurnPhase.simulating] and locks input.
  bool releaseShot() {
    if (_state.phase != CarromTurnPhase.aiming || _isProcessingAction) {
      return false;
    }

    final aimVector = _state.dragAimVector;
    final power = _state.aimPower;

    if (aimVector == null || power <= 0.05) {
      cancelAim();
      return false;
    }

    // Prevent rapid tap/stale action race conditions
    _isProcessingAction = true;
    _actionSequence++;
    _elapsedSimTime = 0.0;
    _coinsPocketedThisShot.clear();

    final shotSpeed = power * CarromConfig.maxShotSpeed;
    final shotVelocity = aimVector.normalized() * shotSpeed;

    final striker = _state.striker.clone()..velocity = shotVelocity;

    _state = _state.copyWith(
      striker: striker,
      phase: CarromTurnPhase.simulating,
      dragAimVector: () => null,
      aimPower: 0.0,
      statusMessage: 'Shot in motion...',
    );

    _notifyListeners();
    return true;
  }

  // --- Physics Simulation Loop ---

  /// Advances physics simulation by [deltaTime].
  /// Typically called by Flutter's Ticker / game loop.
  void tick(double deltaTime) {
    if (_state.phase != CarromTurnPhase.simulating) return;

    _elapsedSimTime += deltaTime;

    // Collect all active objects (coins + striker)
    final allPieces = <CarromCoin>[..._state.coins, _state.striker];

    // Step physics
    final newlyPocketed = CarromPhysics.stepSimulation(
      coins: allPieces,
      deltaTime: deltaTime,
    );

    if (newlyPocketed.isNotEmpty) {
      _coinsPocketedThisShot.addAll(newlyPocketed);
    }

    // Check completion condition: all coins stopped, or safety timeout reached
    final allRest = CarromPhysics.areAllCoinsAtRest(allPieces);
    final timeout = _elapsedSimTime >= CarromConfig.maxSimulationTimeSeconds;

    if (allRest || timeout) {
      // Force all moving pieces to exact zero velocity
      for (final piece in allPieces) {
        piece.velocity = CarromVec2.zero;
      }
      _resolveShotOutcome();
    } else {
      _notifyListeners();
    }
  }

  /// Executes synchronous steps until all pieces come to rest.
  /// Primarily used by unit tests to verify physics and rules instantly.
  void simulateToEndForTesting({double stepDt = 1.0 / 60.0}) {
    if (_state.phase != CarromTurnPhase.simulating) return;

    while (_state.phase == CarromTurnPhase.simulating) {
      tick(stepDt);
    }
  }

  // --- Rule Evaluation & Turn Resolution ---

  void _resolveShotOutcome() {
    final player = _state.currentPlayer.clone();
    final opponent = _state.opponentPlayer.clone();
    final coins = _state.coins.map((c) => c.clone()).toList();

    final strikerPocketed = _coinsPocketedThisShot.any((c) => c.isStriker);
    final queenPocketedThisShot = _coinsPocketedThisShot.any((c) => c.isQueen);
    final whiteCoinsPocketedThisShot =
        _coinsPocketedThisShot.where((c) => c.isWhite).length;
    final blackCoinsPocketedThisShot =
        _coinsPocketedThisShot.where((c) => c.isBlack).length;
    final totalCarromCoinsPocketedThisShot =
        whiteCoinsPocketedThisShot + blackCoinsPocketedThisShot;

    QueenStatus newQueenStatus = _state.queenStatus;
    CarromPlayerId? newQueenPocketedBy = _state.queenPocketedBy;
    var grantExtraShot = false;
    var statusMsg = '';

    // 1. Foul: Striker Pocketed
    if (strikerPocketed) {
      // If queen was pocketed on this shot, it returns to center
      if (queenPocketedThisShot) {
        _returnCoinToCenter(coins, CoinType.queen);
        newQueenStatus = QueenStatus.onBoard;
        newQueenPocketedBy = null;
      } else if (newQueenStatus == QueenStatus.pendingCover &&
          newQueenPocketedBy == player.id) {
        // Queen cover failed due to foul
        _returnCoinToCenter(coins, CoinType.queen);
        newQueenStatus = QueenStatus.onBoard;
        newQueenPocketedBy = null;
      }

      // Credit coins pocketed on this shot BEFORE applying the penalty.
      player.whiteCoinsPocketed += whiteCoinsPocketedThisShot;
      player.blackCoinsPocketed += blackCoinsPocketedThisShot;

      // Penalty: Return 1 previously pocketed coin to center if available
      if (player.pocketedCount > 0) {
        bool returned = false;
        // Return black coin first (standard 10 pt penalty), else white coin (20 pt penalty)
        if (player.blackCoinsPocketed > 0) {
          returned = _returnCoinToCenter(coins, CoinType.black);
          if (returned) {
            player.blackCoinsPocketed--;
          }
        }
        if (!returned && player.whiteCoinsPocketed > 0) {
          returned = _returnCoinToCenter(coins, CoinType.white);
          if (returned) {
            player.whiteCoinsPocketed--;
          }
        }
        if (returned) {
          statusMsg = 'Foul! Striker pocketed. 1 coin penalty returned to center.';
        } else {
          statusMsg = 'Foul! Striker pocketed. Turn ends.';
        }
      } else {
        statusMsg = 'Foul! Striker pocketed. Turn ends.';
      }

      // Turn immediately passes to opponent
      grantExtraShot = false;
    }
    // 2. Normal Shot (No Foul)
    else {
      // Queen logic
      if (queenPocketedThisShot) {
        if (totalCarromCoinsPocketedThisShot >= 1) {
          // Queen covered on the same shot by any coin (black or white)!
          player.hasCoveredQueen = true;
          player.whiteCoinsPocketed += whiteCoinsPocketedThisShot;
          player.blackCoinsPocketed += blackCoinsPocketedThisShot;
          newQueenStatus = QueenStatus.covered;
          newQueenPocketedBy = player.id;
          grantExtraShot = true;
          statusMsg = '${player.name} pocketed and covered Queen! Extra shot.';
        } else {
          // Queen pocketed alone; must be covered next shot by any coin
          newQueenStatus = QueenStatus.pendingCover;
          newQueenPocketedBy = player.id;
          grantExtraShot = true;
          statusMsg = '${player.name} pocketed Queen! Must cover on next shot.';
        }
      } else if (newQueenStatus == QueenStatus.pendingCover &&
          newQueenPocketedBy == player.id) {
        // Player was attempting to cover the Queen
        if (totalCarromCoinsPocketedThisShot >= 1) {
          // Queen covered successfully with any black or white coin!
          player.hasCoveredQueen = true;
          player.whiteCoinsPocketed += whiteCoinsPocketedThisShot;
          player.blackCoinsPocketed += blackCoinsPocketedThisShot;
          newQueenStatus = QueenStatus.covered;
          grantExtraShot = true;
          statusMsg = '${player.name} successfully covered the Queen! Extra shot.';
        } else {
          final remainingOnBoard = coins.where((c) => !c.isStriker && !c.isPocketed);
          if (remainingOnBoard.isNotEmpty) {
            // Queen cover failed: return Queen to center
            _returnCoinToCenter(coins, CoinType.queen);
            newQueenStatus = QueenStatus.onBoard;
            newQueenPocketedBy = null;
            statusMsg = 'Failed to cover Queen. Queen returned to center.';
          }
          grantExtraShot = false;
        }
      } else {
        // Queen was not involved on this shot
        if (totalCarromCoinsPocketedThisShot > 0) {
          // Pocketing any black or white coin scores points for the shooter and grants an extra shot
          player.whiteCoinsPocketed += whiteCoinsPocketedThisShot;
          player.blackCoinsPocketed += blackCoinsPocketedThisShot;
          grantExtraShot = true;
          statusMsg = 'Nice shot! ${player.name} pocketed a coin. Extra shot.';
        } else {
          // No coins pocketed: turn passes
          grantExtraShot = false;
          statusMsg = 'No coin pocketed. Turn passes.';
        }
      }
    }

    // Update players in state
    final p1 = (player.id == CarromPlayerId.player1) ? player : opponent;
    final p2 = (player.id == CarromPlayerId.player2) ? player : opponent;

    assert(() {
      final whiteOnBoard = coins.where((c) => c.isWhite && !c.isPocketed).length;
      final blackOnBoard = coins.where((c) => c.isBlack && !c.isPocketed).length;
      final queenOnBoard = coins.where((c) => c.isQueen && !c.isPocketed).length;

      final totalWhites = coins.where((c) => c.isWhite).length;
      final totalBlacks = coins.where((c) => c.isBlack).length;
      if (totalWhites == CarromConfig.whiteCoinsCount &&
          totalBlacks == CarromConfig.blackCoinsCount &&
          (whiteOnBoard + p1.whiteCoinsPocketed + p2.whiteCoinsPocketed == CarromConfig.whiteCoinsCount) &&
          (blackOnBoard + p1.blackCoinsPocketed + p2.blackCoinsPocketed == CarromConfig.blackCoinsCount)) {
        assert(whiteOnBoard + p1.whiteCoinsPocketed + p2.whiteCoinsPocketed == CarromConfig.whiteCoinsCount);
        assert(blackOnBoard + p1.blackCoinsPocketed + p2.blackCoinsPocketed == CarromConfig.blackCoinsCount);
        assert(queenOnBoard == 1 || newQueenStatus != QueenStatus.onBoard);
      }
      return true;
    }());

    // Empty-board game-over check: Game reaches its normal final board/end condition
    // when all coins on the board are cleared.
    // Finishing one player's original colour does NOT end the game while valid coins remain.
    final remainingCoinsOnBoard = coins.where((c) => !c.isStriker && !c.isPocketed);
    final isBoardEmpty = remainingCoinsOnBoard.isEmpty;

    if (isBoardEmpty) {
      // If the red queen was pocketed but not yet covered when the board becomes empty,
      // count it as covered for the player who pocketed it, so the game never gets stuck.
      if (newQueenStatus == QueenStatus.pendingCover && newQueenPocketedBy != null) {
        final coveringPlayer = (newQueenPocketedBy == CarromPlayerId.player1) ? p1 : p2;
        coveringPlayer.hasCoveredQueen = true;
        newQueenStatus = QueenStatus.covered;
      }

      // Calculate final scores: Black = 10, White = 20, Queen = 50.
      // Winner is strictly determined by highest total score.
      CarromPlayerId? winner;
      if (p1.score > p2.score) {
        winner = CarromPlayerId.player1;
      } else if (p2.score > p1.score) {
        winner = CarromPlayerId.player2;
      } else {
        winner = null; // Draw
      }

      final String endMsg;
      if (winner != null) {
        final winnerName = (winner == CarromPlayerId.player1) ? p1.name : p2.name;
        endMsg = '🏆 $winnerName wins the game!';
      } else {
        endMsg = "Game Over - It's a Draw!";
      }

      _state = _state.copyWith(
        coins: coins,
        player1: p1,
        player2: p2,
        phase: CarromTurnPhase.gameOver,
        winner: () => winner,
        queenStatus: newQueenStatus,
        queenPocketedBy: () => newQueenPocketedBy,
        statusMessage: endMsg,
      );
      _isProcessingAction = false;
      _notifyListeners();
      return;
    }

    // 4. Setup next turn
    final nextTurn = grantExtraShot ? player.id : opponent.id;
    final nextBaselineY = nextTurn.baselineY;
    final nextStrikerX = CarromBoardLayout.clampAndFindValidStrikerX(
      (CarromConfig.baselineMinX + CarromConfig.baselineMaxX) / 2.0,
      nextBaselineY,
      coins,
    );

    final nextStriker = _state.striker.clone()
      ..position = CarromVec2(nextStrikerX, nextBaselineY)
      ..velocity = CarromVec2.zero
      ..isPocketed = false;

    final finalStatus = grantExtraShot
        ? statusMsg
        : '$statusMsg (${nextTurn.displayName}\'s Turn)';

    _state = _state.copyWith(
      coins: coins,
      striker: nextStriker,
      player1: p1,
      player2: p2,
      currentTurn: nextTurn,
      phase: CarromTurnPhase.positioningStriker,
      queenStatus: newQueenStatus,
      queenPocketedBy: () => newQueenPocketedBy,
      statusMessage: finalStatus,
      strikerX: nextStrikerX,
    );

    _isProcessingAction = false;
    _notifyListeners();
  }

  /// Returns a pocketed coin of [type] back to center or nearest free spot.
  /// Returns `true` if a pocketed coin was found and returned, `false` otherwise.
  bool _returnCoinToCenter(List<CarromCoin> coins, CoinType type) {
    for (final coin in coins) {
      if (coin.type == type && coin.isPocketed) {
        final spot = CarromBoardLayout.findNearestFreeCenterSpot(
          coins,
          coinRadius: coin.radius,
        );
        coin.isPocketed = false;
        coin.position = spot;
        coin.velocity = CarromVec2.zero;
        return true;
      }
    }
    return false;
  }

  /// Helper check verifying the Carrom invariant:
  /// For each color: coins on the board + pocketedCount == 9,
  /// and Queen is either on board (1) or off-board (0).
  bool checkBoardInvariants() {
    final whiteOnBoard = _state.coins.where((c) => c.isWhite && !c.isPocketed).length;
    final blackOnBoard = _state.coins.where((c) => c.isBlack && !c.isPocketed).length;
    final queenOnBoard = _state.coins.where((c) => c.isQueen && !c.isPocketed).length;

    final whiteValid = whiteOnBoard +
            _state.player1.whiteCoinsPocketed +
            _state.player2.whiteCoinsPocketed ==
        CarromConfig.whiteCoinsCount;
    final blackValid = blackOnBoard +
            _state.player1.blackCoinsPocketed +
            _state.player2.blackCoinsPocketed ==
        CarromConfig.blackCoinsCount;
    final queenValid = queenOnBoard == 1 || _state.queenStatus != QueenStatus.onBoard;

    return whiteValid && blackValid && queenValid;
  }

  /// Sets state directly for targeted testing scenarios.
  void setStateForTesting(CarromGameState state) {
    _state = state;
    _notifyListeners();
  }
}
