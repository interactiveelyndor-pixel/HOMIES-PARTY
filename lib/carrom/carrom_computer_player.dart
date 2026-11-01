import 'dart:async';
import 'dart:math' as math;

import 'carrom_board_layout.dart';
import 'carrom_config.dart';
import 'carrom_controller.dart';
import 'carrom_game_state.dart';
import 'carrom_models.dart';
import 'carrom_vec2.dart';

/// Result of one computed CPU shot.
class CpuShot {
  final double strikerX;
  final CarromVec2 aimVector; // direction × clamped pull distance (toward target)
  final double power; // 0..1

  const CpuShot({
    required this.strikerX,
    required this.aimVector,
    required this.power,
  });
}

/// Candidate shot evaluated by the AI decision engine.
class _CandidateShot {
  final double strikerX;
  final CarromVec2 strikerPos;
  final CarromVec2 ghostPos;
  final CarromCoin coin;
  final CarromVec2 pocket;
  final double pocketDist;
  final double strikerDist;
  final double cosCut;
  final double score;

  const _CandidateShot({
    required this.strikerX,
    required this.strikerPos,
    required this.ghostPos,
    required this.coin,
    required this.pocket,
    required this.pocketDist,
    required this.strikerDist,
    required this.cosCut,
    required this.score,
  });
}

/// Pure-Dart computer player for Classic Carrom.
///
/// Designed as a fair, realistic MEDIUM-difficulty opponent:
/// - Evaluates available coins (own Black pieces, Queen, and high-value White pots).
/// - Prioritizes Queen cover when Queen is pending cover.
/// - Calculates ghost-ball geometry for practical direct and cut shots into all 4 pockets.
/// - Validates line-of-sight clearance for both coin-to-pocket and striker-to-ghost paths.
/// - Dynamically computes required impulse power using board physics (friction & momentum transfer)
///   to ensure shots reach and drop into pockets without stalling.
/// - Employs a human-like triangular aim error distribution so the AI scores regularly
///   on good looks but occasionally misses on harder cut angles or longer shots.
/// - Never cheats or bypasses physics; interacts strictly through standard [CarromController] methods.
class CarromComputerPlayer {
  final CarromController controller;
  final math.Random _rng;

  bool _disposed = false;
  bool _isTakingTurn = false;
  Timer? _pendingTimer;

  CarromComputerPlayer({
    required this.controller,
    int seed = 42,
  }) : _rng = math.Random(seed);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Release resources and cancel any pending async actions.
  void dispose() {
    _disposed = true;
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  Future<void> _delay(Duration duration) {
    if (_disposed) return Future.value();
    final completer = Completer<void>();
    _pendingTimer?.cancel();
    _pendingTimer = Timer(duration, () {
      _pendingTimer = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  /// Trigger the computer's turn asynchronously.
  ///
  /// Safe to call multiple times — the guard [_isTakingTurn] prevents
  /// overlapping executions. Returns immediately; shot fires after the
  /// configured delay.
  void scheduleTurn() {
    if (_disposed) return;
    if (_isTakingTurn) return;
    _isTakingTurn = true;
    _runTurnAsync();
  }

  // ---------------------------------------------------------------------------
  // Shot computation (pure logic — no async, no side effects)
  // ---------------------------------------------------------------------------

  /// Computes the best available shot for the computer player.
  ///
  /// Exposed with an explicit state parameter so unit tests can call it
  /// without running the async machinery.
  CpuShot computeShot(CarromGameState state) {
    final cpuPlayer = state.currentPlayer;
    final baselineY = state.currentBaselineY;

    final activeCoins =
        state.coins.where((c) => !c.isPocketed && !c.isStriker).toList();

    if (activeCoins.isEmpty) {
      return _fallbackShot(baselineY, state.coins, state);
    }

    final isQueenPendingCover = state.queenStatus == QueenStatus.pendingCover &&
        state.queenPocketedBy == cpuPlayer.id;

    final candidateShots = <_CandidateShot>[];

    for (final coin in activeCoins) {
      for (final pocket in CarromConfig.pocketCenters) {
        final candidate = _evaluatePocketShot(
          coin: coin,
          pocket: pocket,
          baselineY: baselineY,
          activeCoins: activeCoins,
          state: state,
          isQueenPendingCover: isQueenPendingCover,
        );
        if (candidate != null) {
          candidateShots.add(candidate);
        }
      }
    }

    if (candidateShots.isNotEmpty) {
      candidateShots.sort((a, b) => b.score.compareTo(a.score));
      return _buildFinalShot(candidateShots.first);
    }

    return _fallbackShot(baselineY, state.coins, state);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers & async execution
  // ---------------------------------------------------------------------------

  Future<void> _runTurnAsync() async {
    // Keep looping while the CPU earns extra shots.
    while (true) {
      if (_disposed) break;

      final state = controller.state;
      if (state.phase == CarromTurnPhase.gameOver) break;
      if (state.currentTurn != CarromPlayerId.player2) break;
      if (state.phase == CarromTurnPhase.simulating) break;

      // 1. Wait the configured delay so the human can see the board settle.
      await _delay(
        Duration(milliseconds: CarromConfig.cpuShotDelayMs),
      );

      if (_disposed) break;

      // Re-check state after delay — might have changed.
      final stateNow = controller.state;
      if (stateNow.phase == CarromTurnPhase.gameOver) break;
      if (stateNow.currentTurn != CarromPlayerId.player2) break;
      if (stateNow.phase == CarromTurnPhase.simulating) break;

      // 2. Compute and apply the shot.
      final shot = computeShot(stateNow);
      _applyShot(shot);

      if (_disposed) break;

      // 3. Wait for physics to start (give the ticker one frame to kick in).
      await _delay(const Duration(milliseconds: 50));

      if (_disposed) break;

      // 4. Wait until all pieces are at rest (phase exits simulating).
      await _waitForShotToEnd();

      if (_disposed) break;

      // 5. Check whether the CPU earned an extra shot.
      final stateAfter = controller.state;
      if (stateAfter.phase == CarromTurnPhase.gameOver) break;
      if (stateAfter.currentTurn != CarromPlayerId.player2) break;
      // If it's still CPU's turn and back to positioning, loop.
      if (stateAfter.phase == CarromTurnPhase.positioningStriker) {
        // Brief pause between consecutive CPU shots so it is watchable.
        await _delay(
          Duration(milliseconds: CarromConfig.cpuShotDelayMs ~/ 2),
        );
        continue;
      }

      break;
    }

    _isTakingTurn = false;
  }

  /// Polls until the controller exits the [CarromTurnPhase.simulating] phase.
  Future<void> _waitForShotToEnd() async {
    while (!_disposed &&
        controller.state.phase == CarromTurnPhase.simulating) {
      await _delay(const Duration(milliseconds: 30));
    }
  }

  /// Feeds the computed shot into the controller exactly as a human would.
  void _applyShot(CpuShot shot) {
    if (_disposed) return;
    final baselineY = controller.state.currentBaselineY;

    // Position the striker.
    controller.setStrikerPosition(shot.strikerX);

    // Simulate pulling back: aimVector points striker→target (shoot direction).
    // startAiming / updateAim expect the *touch point* (pulled-back position).
    // touchPoint = strikerPosition - aimVector (opposite of shoot direction).
    final strikerPos = CarromVec2(shot.strikerX, baselineY);
    final touchPoint = strikerPos - shot.aimVector;

    controller.startAiming(touchPoint);
    controller.updateAim(touchPoint);
    controller.releaseShot();
  }

  // ---------------------------------------------------------------------------
  // Geometry & Candidate Evaluation
  // ---------------------------------------------------------------------------

  _CandidateShot? _evaluatePocketShot({
    required CarromCoin coin,
    required CarromVec2 pocket,
    required double baselineY,
    required List<CarromCoin> activeCoins,
    required CarromGameState state,
    required bool isQueenPendingCover,
  }) {
    final coinToPocket = pocket - coin.position;
    final pocketDist = coinToPocket.length;
    if (pocketDist < 1.0) return null;

    final shootDir = coinToPocket / pocketDist;

    // Line of sight check: can the coin reach the pocket without hitting other pieces?
    if (!_isPathClear(
      start: coin.position,
      end: pocket,
      radius: coin.radius,
      obstacleCoins: activeCoins,
      ignoreCoinId: coin.id,
    )) {
      return null;
    }

    // Ghost striker position at contact: coin.position - shootDir * (r_striker + r_coin)
    final contactDist = CarromConfig.strikerRadius + coin.radius;
    final ghostPos = coin.position - shootDir * contactDist;

    // Ghost position must reside within playable bounds
    const minGhostBound = CarromConfig.playableMin + CarromConfig.strikerRadius;
    const maxGhostBound = CarromConfig.playableMax - CarromConfig.strikerRadius;
    if (ghostPos.x < minGhostBound ||
        ghostPos.x > maxGhostBound ||
        ghostPos.y < minGhostBound ||
        ghostPos.y > maxGhostBound) {
      return null;
    }

    // Generate candidate striker baseline positions:
    // 1. Analytical ideal collinear striker position
    final candidateXList = <double>[];

    if (shootDir.y.abs() > 0.001) {
      final t = (ghostPos.y - baselineY) / shootDir.y;
      if (t > 0) {
        final idealX = ghostPos.x - t * shootDir.x;
        final clampedIdealX = idealX.clamp(
          CarromConfig.baselineMinX,
          CarromConfig.baselineMaxX,
        );
        candidateXList.add(clampedIdealX);
      }
    }

    // 2. Discrete sampling along the baseline to explore valid cut shot angles
    const step = 18.0;
    for (var x = CarromConfig.baselineMinX;
        x <= CarromConfig.baselineMaxX;
        x += step) {
      candidateXList.add(x);
    }
    candidateXList.add(CarromConfig.baselineMaxX);

    _CandidateShot? bestCandidate;
    double bestScore = -double.infinity;

    for (final rawX in candidateXList) {
      final validX = CarromBoardLayout.clampAndFindValidStrikerX(
        rawX,
        baselineY,
        activeCoins,
      );

      if (!CarromBoardLayout.isStrikerPlacementValid(
        validX,
        baselineY,
        activeCoins,
      )) {
        continue;
      }

      final strikerPos = CarromVec2(validX, baselineY);
      final strikerToGhost = ghostPos - strikerPos;
      final strikerDist = strikerToGhost.length;
      if (strikerDist < 2.0) continue;

      final approachDir = strikerToGhost / strikerDist;
      final cosCut = approachDir.dot(shootDir);

      // Cut angle check: cosCut must be >= 0.35 (cut angle <= ~70°)
      if (cosCut < 0.35) continue;

      // Line of sight check: striker path to ghost position must be clear
      if (!_isPathClear(
        start: strikerPos,
        end: ghostPos,
        radius: CarromConfig.strikerRadius,
        obstacleCoins: activeCoins,
        ignoreCoinId: coin.id,
      )) {
        continue;
      }

      final score = _calculateShotScore(
        coin: coin,
        pocketDist: pocketDist,
        strikerDist: strikerDist,
        cosCut: cosCut,
        state: state,
        isQueenPendingCover: isQueenPendingCover,
      );

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = _CandidateShot(
          strikerX: validX,
          strikerPos: strikerPos,
          ghostPos: ghostPos,
          coin: coin,
          pocket: pocket,
          pocketDist: pocketDist,
          strikerDist: strikerDist,
          cosCut: cosCut,
          score: score,
        );
      }
    }

    return bestCandidate;
  }

  /// Calculates an overall desirability score for a candidate shot.
  double _calculateShotScore({
    required CarromCoin coin,
    required double pocketDist,
    required double strikerDist,
    required double cosCut,
    required CarromGameState state,
    required bool isQueenPendingCover,
  }) {
    double score = 0.0;

    // 1. Piece prioritization
    if (isQueenPendingCover) {
      // Must cover Queen on this turn; any potted coin completes cover.
      score += 100.0;
    } else if (coin.isQueen) {
      score += 35.0; // High value target (50 pts)
    } else if (coin.isBlack) {
      score += 25.0; // Assigned CPU color
    } else {
      score += 12.0; // Opponent White piece (still scores points and extra turn)
    }

    // 2. Cut angle alignment bonus (straighter shots are vastly more reliable)
    // Using 4th power strongly favors straight collinear shots (cosCut ≈ 1.0)
    score += math.pow(cosCut, 4) * 35.0;

    // 3. Proximity to pocket (closer = easier pot)
    final pocketProximity =
        (1.0 - (pocketDist / CarromConfig.boardSize)).clamp(0.0, 1.0);
    score += pocketProximity * 20.0;

    // 4. Proximity of striker to coin (closer striker = less travel error)
    final strikerProximity =
        (1.0 - (strikerDist / CarromConfig.boardSize)).clamp(0.0, 1.0);
    score += strikerProximity * 8.0;

    // 5. Easy tap-in bonus for hanging coins
    if (pocketDist < 120.0) {
      score += 15.0;
    }

    return score;
  }

  /// Checks whether a circular piece of [radius] can travel along the line segment
  /// from [start] to [end] without colliding with any other active coin.
  bool _isPathClear({
    required CarromVec2 start,
    required CarromVec2 end,
    required double radius,
    required List<CarromCoin> obstacleCoins,
    required int ignoreCoinId,
  }) {
    final segment = end - start;
    final segLenSq = segment.lengthSquared;
    if (segLenSq < 1e-4) return true;

    for (final obstacle in obstacleCoins) {
      if (obstacle.id == ignoreCoinId) continue;
      if (obstacle.isPocketed || obstacle.isStriker) continue;

      final toObstacle = obstacle.position - start;
      final t = (toObstacle.dot(segment) / segLenSq).clamp(0.0, 1.0);
      final closestPoint = start + segment * t;
      final distSq = closestPoint.distanceSquaredTo(obstacle.position);

      final minAllowedDist = radius + obstacle.radius + 1.5;
      if (distSq < minAllowedDist * minAllowedDist) {
        return false;
      }
    }

    return true;
  }

  /// Constructs the final [CpuShot] with physics-based impulse power and realistic
  /// medium-difficulty aim variance.
  CpuShot _buildFinalShot(_CandidateShot candidate) {
    final aimDir = (candidate.ghostPos - candidate.strikerPos).normalized();

    // Human-like triangular error distribution: peaks at 0, rare maximum variance.
    final errorFactor = _rng.nextDouble() - _rng.nextDouble(); // [-1.0, 1.0]
    final maxAngleError = CarromConfig.cpuAimErrorRadians * 0.50; // ≈ 2.0 degrees max
    final angleError = errorFactor * maxAngleError;

    final cosE = math.cos(angleError);
    final sinE = math.sin(angleError);
    final adjustedAimDir = CarromVec2(
      aimDir.x * cosE - aimDir.y * sinE,
      aimDir.x * sinE + aimDir.y * cosE,
    ).normalized();

    // Physics power calculation:
    // Required coin speed to comfortably reach the pocket and drop cleanly:
    const aEff = 340.0;
    const vResidual = 300.0;
    final vCoinSq = (2.0 * aEff * candidate.pocketDist) + (vResidual * vResidual);
    final vCoin = math.sqrt(vCoinSq);

    // Momentum transfer: v_coin = 1.425 * v_impact * cosCut
    final effectiveCos = candidate.cosCut.clamp(0.35, 1.0);
    final vImpact = vCoin / (1.425 * effectiveCos);

    // Striker launch speed: v_launch^2 = v_impact^2 + 2 * a_eff * d_striker
    final vLaunchSq = (vImpact * vImpact) + (2.0 * aEff * candidate.strikerDist);
    final vLaunch = math.sqrt(vLaunchSq);

    final rawPower = vLaunch / CarromConfig.maxShotSpeed;
    final powerJitter = (_rng.nextDouble() - 0.5) * 0.04;

    // Calibrated confident medium power range (0.48 to 0.98)
    final finalPower = ((rawPower * 1.18) + powerJitter).clamp(0.48, 0.98);
    final pullDist = finalPower * CarromConfig.maxPullDistance;

    return CpuShot(
      strikerX: candidate.strikerX,
      aimVector: adjustedAimDir * pullDist,
      power: finalPower,
    );
  }

  /// Fallback: when all direct pocket paths are obstructed, target the most
  /// accessible coin with confident break/scatter power to open the board.
  CpuShot _fallbackShot(
    double baselineY,
    List<CarromCoin> allCoins,
    CarromGameState state,
  ) {
    final activeCoins =
        allCoins.where((c) => !c.isPocketed && !c.isStriker).toList();

    final midX =
        (CarromConfig.baselineMinX + CarromConfig.baselineMaxX) / 2.0;

    if (activeCoins.isEmpty) {
      final safeX = CarromBoardLayout.clampAndFindValidStrikerX(
        midX,
        baselineY,
        allCoins,
      );
      final dir =
          (CarromConfig.centerPoint - CarromVec2(safeX, baselineY)).normalized();
      const power = 0.55;
      return CpuShot(
        strikerX: safeX,
        aimVector: dir * (power * CarromConfig.maxPullDistance),
        power: power,
      );
    }

    CarromCoin? bestTarget;
    double bestScore = -double.infinity;
    double bestStrikerX = midX;

    for (final coin in activeCoins) {
      final testX = CarromBoardLayout.clampAndFindValidStrikerX(
        coin.position.x,
        baselineY,
        activeCoins,
      );

      final strikerPos = CarromVec2(testX, baselineY);
      final toCoin = coin.position - strikerPos;
      final dist = toCoin.length;
      if (dist < 1.0) continue;

      final clear = _isPathClear(
        start: strikerPos,
        end: coin.position,
        radius: CarromConfig.strikerRadius,
        obstacleCoins: activeCoins,
        ignoreCoinId: coin.id,
      );

      var score = 100.0 - dist;
      if (coin.isBlack) score += 30.0;
      if (coin.isQueen) score += 40.0;
      if (clear) score += 50.0;

      if (score > bestScore) {
        bestScore = score;
        bestTarget = coin;
        bestStrikerX = testX;
      }
    }

    final target = bestTarget ?? activeCoins.first;
    final strikerPos = CarromVec2(bestStrikerX, baselineY);
    final dir = (target.position - strikerPos).normalized();

    final jitter = (_rng.nextDouble() - _rng.nextDouble()) * 0.04;
    final cosJ = math.cos(jitter);
    final sinJ = math.sin(jitter);
    final aimedDir = CarromVec2(
      dir.x * cosJ - dir.y * sinJ,
      dir.x * sinJ + dir.y * cosJ,
    ).normalized();

    final power = (0.62 + (_rng.nextDouble() * 0.14)).clamp(0.55, 0.85);
    final pullDist = power * CarromConfig.maxPullDistance;

    return CpuShot(
      strikerX: bestStrikerX,
      aimVector: aimedDir * pullDist,
      power: power,
    );
  }
}
