import 'dart:math' as math;
import 'carrom_config.dart';
import 'carrom_models.dart';
import 'carrom_vec2.dart';

/// Helper for setting up initial standard carrom layouts and finding free spots.
class CarromBoardLayout {
  CarromBoardLayout._();

  /// Generates the standard 19-piece circular Carrom layout:
  /// - 1 Red Queen at the exact center (400, 400).
  /// - 6 coins in the inner ring (3 White, 3 Black alternating).
  /// - 12 coins in the outer ring (6 White, 6 Black).
  /// Total: 9 White, 9 Black, 1 Queen.
  static List<CarromCoin> createInitialCoins() {
    final coins = <CarromCoin>[];
    var nextId = 1;

    final center = CarromConfig.centerPoint;
    final r = CarromConfig.coinRadius;

    // 1. Center Red Queen
    coins.add(
      CarromCoin(
        id: nextId++,
        type: CoinType.queen,
        position: center,
      ),
    );

    // 2. Inner Ring: 6 coins tightly packed around Queen
    // Distance from center = 2 * r (coins touch Queen)
    final innerDist = 2.0 * r;
    // Alternate White and Black: W, B, W, B, W, B
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60.0) * (math.pi / 180.0);
      final pos = CarromVec2(
        center.x + innerDist * math.cos(angle),
        center.y + innerDist * math.sin(angle),
      );
      final type = (i % 2 == 0) ? CoinType.white : CoinType.black;
      coins.add(
        CarromCoin(
          id: nextId++,
          type: type,
          position: pos,
        ),
      );
    }

    // 3. Outer Ring: 12 coins tightly packed around inner ring
    // 6 corner vertices at angle = i * 60 deg, dist = 4 * r
    // 6 edge midpoints at angle = (i * 60 + 30) deg, dist = 2 * sqrt(3) * r
    final outerCornerDist = 4.0 * r;
    final outerEdgeDist = 2.0 * math.sqrt(3.0) * r;

    // To have 6 White and 6 Black in the outer ring (total 9 each):
    // Inner has 3 White, 3 Black.
    // Outer needs 6 White, 6 Black.
    // We alternate in pairs or alternating round:
    // Angles in order: 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330
    final outerPattern = [
      CoinType.black,
      CoinType.white,
      CoinType.white,
      CoinType.black,
      CoinType.black,
      CoinType.white,
      CoinType.white,
      CoinType.black,
      CoinType.black,
      CoinType.white,
      CoinType.white,
      CoinType.black,
    ];

    for (var i = 0; i < 12; i++) {
      final angleDeg = i * 30.0;
      final angleRad = angleDeg * (math.pi / 180.0);
      final isCorner = (i % 2 == 0);
      final dist = isCorner ? outerCornerDist : outerEdgeDist;

      final pos = CarromVec2(
        center.x + dist * math.cos(angleRad),
        center.y + dist * math.sin(angleRad),
      );

      coins.add(
        CarromCoin(
          id: nextId++,
          type: outerPattern[i],
          position: pos,
        ),
      );
    }

    return coins;
  }

  /// Finds the nearest free position starting from center (400, 400)
  /// that does not overlap with any active coin or the striker.
  static CarromVec2 findNearestFreeCenterSpot(
    List<CarromCoin> activeCoins, {
    double coinRadius = CarromConfig.coinRadius,
  }) {
    final center = CarromConfig.centerPoint;

    // Check if the exact center point is free
    if (isSpotFree(center, coinRadius, activeCoins)) {
      return center;
    }

    // Spiral search outward in radial increments
    const stepRadius = 4.0;
    const maxSearchRadius = 200.0;
    const angleSteps = 36; // Every 10 degrees

    for (var r = stepRadius; r <= maxSearchRadius; r += stepRadius) {
      for (var a = 0; a < angleSteps; a++) {
        final angle = a * (2 * math.pi / angleSteps);
        final candidate = CarromVec2(
          center.x + r * math.cos(angle),
          center.y + r * math.sin(angle),
        );

        // Ensure inside playable bounds
        if (candidate.x < CarromConfig.playableMin + coinRadius ||
            candidate.x > CarromConfig.playableMax - coinRadius ||
            candidate.y < CarromConfig.playableMin + coinRadius ||
            candidate.y > CarromConfig.playableMax - coinRadius) {
          continue;
        }

        if (isSpotFree(candidate, coinRadius, activeCoins)) {
          return candidate;
        }
      }
    }

    // Fallback: return center if all else fails
    return center;
  }

  /// Checks if a candidate circle does not overlap with any active coin.
  static bool isSpotFree(
    CarromVec2 candidate,
    double radius,
    List<CarromCoin> activeCoins,
  ) {
    for (final coin in activeCoins) {
      if (coin.isPocketed) continue;
      final minAllowedDist = radius + coin.radius;
      if (candidate.distanceSquaredTo(coin.position) <
          (minAllowedDist * minAllowedDist) - 0.5) {
        return false;
      }
    }
    return true;
  }

  /// Checks if a striker placement at (x, baselineY) overlaps any active coin.
  static bool isStrikerPlacementValid(
    double x,
    double baselineY,
    List<CarromCoin> activeCoins,
  ) {
    if (x < CarromConfig.baselineMinX || x > CarromConfig.baselineMaxX) {
      return false;
    }

    final strikerPos = CarromVec2(x, baselineY);
    for (final coin in activeCoins) {
      if (coin.isPocketed || coin.isStriker) continue;
      final minAllowed = CarromConfig.strikerRadius + coin.radius;
      if (strikerPos.distanceSquaredTo(coin.position) < minAllowed * minAllowed) {
        return false;
      }
    }
    return true;
  }

  /// Finds the closest valid X coordinate on the baseline to [desiredX].
  static double clampAndFindValidStrikerX(
    double desiredX,
    double baselineY,
    List<CarromCoin> activeCoins,
  ) {
    final clampedX = desiredX.clamp(
      CarromConfig.baselineMinX,
      CarromConfig.baselineMaxX,
    );

    if (isStrikerPlacementValid(clampedX, baselineY, activeCoins)) {
      return clampedX;
    }

    // Search left and right for nearest legal X
    const step = 2.0;
    final maxOffset = CarromConfig.baselineMaxX - CarromConfig.baselineMinX;

    for (var offset = step; offset <= maxOffset; offset += step) {
      final rightX = clampedX + offset;
      if (rightX <= CarromConfig.baselineMaxX &&
          isStrikerPlacementValid(rightX, baselineY, activeCoins)) {
        return rightX;
      }

      final leftX = clampedX - offset;
      if (leftX >= CarromConfig.baselineMinX &&
          isStrikerPlacementValid(leftX, baselineY, activeCoins)) {
        return leftX;
      }
    }

    // Fallback: clamped position
    return clampedX;
  }
}
