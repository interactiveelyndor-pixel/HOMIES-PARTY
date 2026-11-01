import 'carrom_config.dart';
import 'carrom_models.dart';
import 'carrom_vec2.dart';

/// Pure Dart deterministic 2D physics engine for Carrom.
/// Handles sub-stepped momentum transfer, wall rebounds, friction,
/// pocket detection, and velocity capping.
class CarromPhysics {
  /// Steps all active coins forward by [deltaTime] seconds using fixed sub-stepping.
  /// Returns the list of coins that were pocketed during this step.
  static List<CarromCoin> stepSimulation({
    required List<CarromCoin> coins,
    required double deltaTime,
  }) {
    final newlyPocketed = <CarromCoin>[];
    if (coins.isEmpty) return newlyPocketed;

    // Split frame into smaller sub-steps for collision precision and no tunneling
    final subStepDt = CarromConfig.fixedDeltaTime;
    var accumulatedTime = 0.0;

    while (accumulatedTime < deltaTime) {
      final currentSubStep = (deltaTime - accumulatedTime < subStepDt)
          ? (deltaTime - accumulatedTime)
          : subStepDt;

      // 1. Move all non-pocketed coins
      for (final coin in coins) {
        if (coin.isPocketed) continue;
        if (coin.velocity.lengthSquared > 0.0) {
          // Cap velocity
          coin.velocity = coin.velocity.clampedLength(CarromConfig.maxVelocity);
          coin.position += coin.velocity * currentSubStep;
        }
      }

      // 2. Check pocket falls
      for (final coin in coins) {
        if (coin.isPocketed) continue;
        for (final pocket in CarromConfig.pocketCenters) {
          final distSq = coin.position.distanceSquaredTo(pocket);
          // Pocket threshold: when coin center is within pocket radius
          if (distSq <= CarromConfig.pocketRadius * CarromConfig.pocketRadius) {
            coin.isPocketed = true;
            coin.velocity = CarromVec2.zero;
            coin.position = pocket;
            newlyPocketed.add(coin);
            break;
          }
        }
      }

      // 3. Wall collisions (skip if coin is very close to a pocket)
      for (final coin in coins) {
        if (coin.isPocketed) continue;
        _resolveWallCollision(coin);
      }

      // 4. Circle-to-circle collisions (momentum transfer)
      for (var i = 0; i < coins.length; i++) {
        final coinA = coins[i];
        if (coinA.isPocketed) continue;

        for (var j = i + 1; j < coins.length; j++) {
          final coinB = coins[j];
          if (coinB.isPocketed) continue;

          _resolveCircleCollision(coinA, coinB);
        }
      }

      // 5. Apply friction deceleration
      for (final coin in coins) {
        if (coin.isPocketed) continue;
        _applyFriction(coin, currentSubStep);
      }

      accumulatedTime += currentSubStep;
    }

    return newlyPocketed;
  }

  /// Resolves collision with the 4 wooden borders.
  static void _resolveWallCollision(CarromCoin coin) {
    // If the coin is in the corner pocket mouth, allow it to pass into pocket
    for (final pocket in CarromConfig.pocketCenters) {
      if (coin.position.distanceSquaredTo(pocket) <
          (CarromConfig.pocketRadius + 14.0) *
              (CarromConfig.pocketRadius + 14.0)) {
        return;
      }
    }

    final minBound = CarromConfig.playableMin + coin.radius;
    final maxBound = CarromConfig.playableMax - coin.radius;
    final e = CarromConfig.wallRestitution;

    // Left wall
    if (coin.position.x < minBound) {
      coin.position = CarromVec2(minBound, coin.position.y);
      if (coin.velocity.x < 0) {
        coin.velocity = CarromVec2(-coin.velocity.x * e, coin.velocity.y);
      }
    }
    // Right wall
    else if (coin.position.x > maxBound) {
      coin.position = CarromVec2(maxBound, coin.position.y);
      if (coin.velocity.x > 0) {
        coin.velocity = CarromVec2(-coin.velocity.x * e, coin.velocity.y);
      }
    }

    // Top wall
    if (coin.position.y < minBound) {
      coin.position = CarromVec2(coin.position.x, minBound);
      if (coin.velocity.y < 0) {
        coin.velocity = CarromVec2(coin.velocity.x, -coin.velocity.y * e);
      }
    }
    // Bottom wall
    else if (coin.position.y > maxBound) {
      coin.position = CarromVec2(coin.position.x, maxBound);
      if (coin.velocity.y > 0) {
        coin.velocity = CarromVec2(coin.velocity.x, -coin.velocity.y * e);
      }
    }
  }

  /// Resolves elastic collision between two circular coins with momentum transfer.
  static void _resolveCircleCollision(CarromCoin a, CarromCoin b) {
    final delta = a.position - b.position;
    final distSq = delta.lengthSquared;
    final radiusSum = a.radius + b.radius;

    if (distSq >= radiusSum * radiusSum || distSq == 0.0) {
      return;
    }

    final dist = delta.length;
    final normal = delta / dist;

    // Positional separation to prevent sinking
    final overlap = radiusSum - dist;
    final totalMass = a.mass + b.mass;
    final aRatio = b.mass / totalMass;
    final bRatio = a.mass / totalMass;

    a.position += normal * (overlap * aRatio);
    b.position -= normal * (overlap * bRatio);

    // Relative velocity along collision normal
    final relVel = a.velocity - b.velocity;
    final velAlongNormal = relVel.dot(normal);

    // If already moving apart, do not apply impulse
    if (velAlongNormal > 0.0) return;

    // Restitution selection
    final e = (a.isStriker || b.isStriker)
        ? CarromConfig.strikerCoinRestitution
        : CarromConfig.coinRestitution;

    // Impulse magnitude: J = -(1 + e) * v_n / (1/m1 + 1/m2)
    final impulseMag = -(1.0 + e) * velAlongNormal / ((1.0 / a.mass) + (1.0 / b.mass));
    final impulse = normal * impulseMag;

    a.velocity += impulse / a.mass;
    b.velocity -= impulse / b.mass;
  }

  /// Applies surface friction and damping to bring coins to a clean, natural stop.
  static void _applyFriction(CarromCoin coin, double dt) {
    final speed = coin.velocity.length;
    if (speed == 0.0) return;

    if (speed < CarromConfig.stopThreshold) {
      coin.velocity = CarromVec2.zero;
      return;
    }

    // Linear friction + viscous damping
    var newSpeed = speed - CarromConfig.frictionDeceleration * dt;
    newSpeed *= (1.0 - CarromConfig.viscousDamping * dt);

    if (newSpeed < CarromConfig.stopThreshold) {
      coin.velocity = CarromVec2.zero;
    } else {
      coin.velocity = coin.velocity * (newSpeed / speed);
    }
  }

  /// Returns true if all coins are at rest (velocity is zero).
  static bool areAllCoinsAtRest(List<CarromCoin> coins) {
    for (final coin in coins) {
      if (coin.isPocketed) continue;
      if (coin.velocity.lengthSquared > 0.0) {
        return false;
      }
    }
    return true;
  }
}
