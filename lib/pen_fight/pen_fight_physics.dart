import 'dart:math' as math;
import 'pen_fight_config.dart';
import 'pen_fight_models.dart';
import 'pen_fight_vec2.dart';

class _SegmentSegmentResult {
  final PenFightVec2 point1;
  final PenFightVec2 point2;
  final double distance;

  const _SegmentSegmentResult(this.point1, this.point2, this.distance);
}

/// Pure Dart deterministic 2D rigid-body physics engine for Pen Fight.
/// Has zero Flutter or dart:ui dependencies.
///
/// Features:
/// - Fixed sub-stepping for deterministic simulation across all devices
/// - Capsule rigid bodies with 2D rotation, torque, and contact impulses
/// - Off-center collisions apply realistic torque and spin; center hits slide straight
/// - Dynamic surface sliding friction, angular friction, and viscous damping
/// - Table edge balance: pen falls only when center of mass crosses the edge
/// - Overhanging pens balance and pivot around table edge
/// - Linear and angular velocity capping to prevent physics tunneling
class PenFightPhysics {
  /// Steps the physics simulation forward by [deltaTime] seconds.
  /// Sub-steps the integration using [PenFightConfig.fixedTimestep] / [PenFightConfig.physicsSubSteps].
  static void stepSimulation({
    required Pen pen1,
    required Pen pen2,
    required double deltaTime,
    PenFightTableType tableType = PenFightTableType.classic,
  }) {
    if (deltaTime <= 0.0) return;

    final subStepDt = PenFightConfig.fixedTimestep / PenFightConfig.physicsSubSteps;
    var accumulatedTime = 0.0;

    while (accumulatedTime < deltaTime) {
      final currentSubStep = (deltaTime - accumulatedTime < subStepDt)
          ? (deltaTime - accumulatedTime)
          : subStepDt;

      _subStep(pen1, pen2, currentSubStep, tableType);
      accumulatedTime += currentSubStep;
    }
  }

  static void _subStep(Pen pen1, Pen pen2, double dt, PenFightTableType tableType) {
    // 1. Move active pens (integrate position and rotation)
    _integrateMotion(pen1, dt);
    _integrateMotion(pen2, dt);

    // 2. Check table bounds & hazards (edge falloff, center hole)
    _checkTableBounds(pen1, tableType);
    _checkTableBounds(pen2, tableType);

    // 3. Capsule rigid body collision between pens (only if both are still on table)
    if (!pen1.isOffTable && !pen2.isOffTable) {
      _resolveCapsuleCollision(pen1, pen2);
    }

    // 5. Apply surface friction, angular spin deceleration, and overhanging edge torque
    _applyFriction(pen1, dt);
    _applyFriction(pen2, dt);
  }

  static void _integrateMotion(Pen pen, double dt) {
    if (pen.isOffTable) {
      // Once off table, animate fall progress and damp remaining speed
      if (pen.fallProgress < 1.0) {
        pen.fallProgress = (pen.fallProgress + dt * 2.5).clamp(0.0, 1.0);
        pen.position += pen.velocity * (dt * 0.4);
        pen.angle += pen.angularVelocity * (dt * 0.4);
      } else {
        pen.velocity = PenFightVec2.zero;
        pen.angularVelocity = 0.0;
      }
      return;
    }

    // Cap maximum linear velocity
    pen.velocity = pen.velocity.clampedLength(PenFightConfig.maxSpeed);

    // Cap maximum angular velocity
    pen.angularVelocity = pen.angularVelocity.clamp(
      -PenFightConfig.maxAngularSpeed,
      PenFightConfig.maxAngularSpeed,
    );

    // Position integration
    if (pen.velocity.lengthSquared > 0.0) {
      pen.position += pen.velocity * dt;
    }

    // Angle integration
    if (pen.angularVelocity.abs() > 0.0) {
      pen.angle += pen.angularVelocity * dt;
      // Normalize angle to [-pi, pi]
      pen.angle = _normalizeAngle(pen.angle);
    }
  }

  static double _normalizeAngle(double angle) {
    var a = angle % (2 * math.pi);
    if (a > math.pi) a -= 2 * math.pi;
    if (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  /// Table hazard & edge fall condition:
  /// - Classic: falls if center of mass passes any edge.
  /// - Hole: falls if center of mass passes any edge OR enters the center hole.
  static void _checkTableBounds(Pen pen, PenFightTableType tableType) {
    if (pen.isOffTable) return;

    final x = pen.position.x;
    final y = pen.position.y;
    final w = PenFightConfig.tableWidth;
    final h = PenFightConfig.tableHeight;

    switch (tableType) {
      case PenFightTableType.classic:
        if (x < 0.0 || x > w || y < 0.0 || y > h) {
          pen.isOffTable = true;
          pen.fallProgress = 0.0;
        }
        break;

      case PenFightTableType.hole:
        // Open edges fall
        if (x < 0.0 || x > w || y < 0.0 || y > h) {
          pen.isOffTable = true;
          pen.fallProgress = 0.0;
          return;
        }
        // Center hole fall
        final distToHole = pen.position.distanceTo(PenFightConfig.holeCenter);
        if (distToHole <= PenFightConfig.holeRadius) {
          pen.isOffTable = true;
          pen.fallProgress = 0.0;
        }
        break;
    }
  }

  /// Finds the closest points between two line segments S1 [p1, q1] and S2 [p2, q2].
  static _SegmentSegmentResult _closestPointsOnSegments(
    PenFightVec2 p1,
    PenFightVec2 q1,
    PenFightVec2 p2,
    PenFightVec2 q2,
  ) {
    final d1 = q1 - p1;
    final d2 = q2 - p2;
    final r = p1 - p2;

    final a = d1.lengthSquared;
    final e = d2.lengthSquared;
    final f = d2.dot(r);

    double s;
    double t;

    if (a <= 1e-8 && e <= 1e-8) {
      s = 0.0;
      t = 0.0;
    } else if (a <= 1e-8) {
      s = 0.0;
      t = (f / e).clamp(0.0, 1.0);
    } else if (e <= 1e-8) {
      t = 0.0;
      s = (-d1.dot(r) / a).clamp(0.0, 1.0);
    } else {
      final c = d1.dot(r);
      final b = d1.dot(d2);
      final denom = a * e - b * b;

      if (denom.abs() > 1e-8) {
        s = ((b * f - c * e) / denom).clamp(0.0, 1.0);
      } else {
        s = 0.0;
      }

      t = (b * s + f) / e;

      if (t < 0.0) {
        t = 0.0;
        s = (-c / a).clamp(0.0, 1.0);
      } else if (t > 1.0) {
        t = 1.0;
        s = ((b - c) / a).clamp(0.0, 1.0);
      }
    }

    final closest1 = p1 + (d1 * s);
    final closest2 = p2 + (d2 * t);
    final dist = closest1.distanceTo(closest2);

    return _SegmentSegmentResult(closest1, closest2, dist);
  }

  /// Resolves capsule-to-capsule rigid body collision using contact point,
  /// normal restitution impulse, tangential friction, and angular torque.
  static void _resolveCapsuleCollision(Pen a, Pen b) {
    final segResult = _closestPointsOnSegments(
      a.spinePointA,
      a.spinePointB,
      b.spinePointA,
      b.spinePointB,
    );

    final radiusSum = a.radius + b.radius;
    if (segResult.distance >= radiusSum) {
      return; // No collision: pens miss each other
    }

    final dist = segResult.distance;
    final overlap = radiusSum - dist;

    // Normal vector pointing from b to a
    PenFightVec2 normal;
    if (dist > 1e-5) {
      normal = (segResult.point1 - segResult.point2) / dist;
    } else {
      final delta = a.position - b.position;
      normal = delta.length > 1e-5 ? delta.normalized() : const PenFightVec2(0.0, -1.0);
    }

    // Contact point between the two capsules (midpoint of the contact region)
    final contactPoint = (segResult.point1 + segResult.point2) * 0.5;

    // Positional separation to prevent sinking
    final invMassA = 1.0 / a.mass;
    final invMassB = 1.0 / b.mass;
    final totalInvMass = invMassA + invMassB;

    a.position += normal * (overlap * (invMassA / totalInvMass));
    b.position -= normal * (overlap * (invMassB / totalInvMass));

    // Lever arms from centers of mass to contact point
    final rA = contactPoint - a.position;
    final rB = contactPoint - b.position;

    // Contact point velocities: v_c = v + (omega x r)
    // In 2D: (omega x r) = (-omega * r.y, omega * r.x)
    final vAContact = a.velocity + PenFightVec2(-a.angularVelocity * rA.y, a.angularVelocity * rA.x);
    final vBContact = b.velocity + PenFightVec2(-b.angularVelocity * rB.y, b.angularVelocity * rB.x);

    final relVel = vAContact - vBContact;
    final velAlongNormal = relVel.dot(normal);

    // If moving apart, do not apply collision impulse
    if (velAlongNormal >= 0.0) return;

    final invIA = 1.0 / a.momentOfInertia;
    final invIB = 1.0 / b.momentOfInertia;

    // 2D Cross product: r x normal = r.x * normal.y - r.y * normal.x
    final rACrossN = rA.cross(normal);
    final rBCrossN = rB.cross(normal);

    final kn = invMassA + invMassB + (rACrossN * rACrossN * invIA) + (rBCrossN * rBCrossN * invIB);
    if (kn <= 0.0) return;

    // Normal impulse scalar
    final jn = -(1.0 + PenFightConfig.bounce) * velAlongNormal / kn;
    final impulseN = normal * jn;

    // Tangential Coulomb friction impulse
    final tangent = PenFightVec2(-normal.y, normal.x);
    final vt = relVel.dot(tangent);
    final rACrossT = rA.cross(tangent);
    final rBCrossT = rB.cross(tangent);

    final kt = invMassA + invMassB + (rACrossT * rACrossT * invIA) + (rBCrossT * rBCrossT * invIB);
    var jt = kt > 0.0 ? (-vt / kt) : 0.0;
    final maxJt = PenFightConfig.contactFriction * jn;
    jt = jt.clamp(-maxJt, maxJt);
    final impulseT = tangent * jt;

    final totalImpulse = impulseN + impulseT;

    // Apply linear and angular impulse
    a.velocity += totalImpulse * invMassA;
    a.angularVelocity += rA.cross(totalImpulse) * invIA;

    b.velocity -= totalImpulse * invMassB;
    b.angularVelocity -= rB.cross(totalImpulse) * invIB;

    // Cap velocities
    a.velocity = a.velocity.clampedLength(PenFightConfig.maxSpeed);
    b.velocity = b.velocity.clampedLength(PenFightConfig.maxSpeed);
    a.angularVelocity = a.angularVelocity.clamp(
      -PenFightConfig.maxAngularSpeed,
      PenFightConfig.maxAngularSpeed,
    );
    b.angularVelocity = b.angularVelocity.clamp(
      -PenFightConfig.maxAngularSpeed,
      PenFightConfig.maxAngularSpeed,
    );
  }

  /// Dynamic sliding surface friction, angular friction, viscous damping,
  /// and overhanging edge pivot torque.
  static void _applyFriction(Pen pen, double dt) {
    if (pen.isOffTable) return;

    // 1. Linear sliding friction & viscous damping
    final speed = pen.velocity.length;
    if (speed > 0.0) {
      if (speed < PenFightConfig.stopThreshold) {
        pen.velocity = PenFightVec2.zero;
      } else {
        var newSpeed = speed - PenFightConfig.friction * dt;
        newSpeed *= (1.0 - PenFightConfig.viscousDamping * dt);

        if (newSpeed < PenFightConfig.stopThreshold) {
          pen.velocity = PenFightVec2.zero;
        } else {
          pen.velocity = pen.velocity * (newSpeed / speed);
        }
      }
    }

    // 2. Angular friction & viscous damping
    final spinSpeed = pen.angularVelocity.abs();
    if (spinSpeed > 0.0) {
      if (spinSpeed < PenFightConfig.angularStopThreshold) {
        pen.angularVelocity = 0.0;
      } else {
        var newSpin = spinSpeed - PenFightConfig.angularFriction * dt;
        newSpin *= (1.0 - PenFightConfig.angularViscousDamping * dt);

        if (newSpin < PenFightConfig.angularStopThreshold) {
          pen.angularVelocity = 0.0;
        } else {
          pen.angularVelocity = (pen.angularVelocity > 0 ? 1.0 : -1.0) * newSpin;
        }
      }
    }

    // 3. Overhanging edge balance and pivot torque
    // If the pen center of mass is on the table, but some of its body overhangs the edge,
    // the supported portion applies asymmetric friction torque that pivots the pen!
    _applyOverhangEdgePhysics(pen, dt);
  }

  static void _applyOverhangEdgePhysics(Pen pen, double dt) {
    final pA = pen.spinePointA;
    final pB = pen.spinePointB;
    const samples = PenFightConfig.spineSampleCount;

    var insideCount = 0;
    var sumInsideX = 0.0;
    var sumInsideY = 0.0;

    for (var i = 0; i < samples; i++) {
      final t = i / (samples - 1);
      final px = pA.x + (pB.x - pA.x) * t;
      final py = pA.y + (pB.y - pA.y) * t;

      if (px >= 0.0 &&
          px <= PenFightConfig.tableWidth &&
          py >= 0.0 &&
          py <= PenFightConfig.tableHeight) {
        insideCount++;
        sumInsideX += px;
        sumInsideY += py;
      }
    }

    // If partially overhanging the table edge
    if (insideCount > 0 && insideCount < samples && pen.velocity.lengthSquared > 1.0) {
      final centerOfSupport = PenFightVec2(
        sumInsideX / insideCount,
        sumInsideY / insideCount,
      );
      final rSupport = centerOfSupport - pen.position;

      // Friction force on the supported portion
      final fricDir = -pen.velocity.normalized();
      final fricMag = PenFightConfig.friction * pen.mass * (insideCount / samples);
      final fricForce = fricDir * fricMag;

      // Torque around center of mass: tau = rSupport x fricForce
      final torque = rSupport.cross(fricForce) * PenFightConfig.overhangTorqueFactor;
      final angularAcc = torque / pen.momentOfInertia;
      pen.angularVelocity += angularAcc * dt;
    }
  }

  /// Returns true when all motion (linear AND angular) has stopped:
  /// pens are either completely stopped on the table or finished falling off.
  static bool areAllPensAtRest(Pen pen1, Pen pen2) {
    bool isPenResting(Pen pen) {
      if (pen.isOffTable) {
        return pen.fallProgress >= 1.0 ||
            (pen.velocity.lengthSquared == 0.0 && pen.angularVelocity == 0.0);
      }
      return pen.velocity.lengthSquared == 0.0 && pen.angularVelocity.abs() == 0.0;
    }

    return isPenResting(pen1) && isPenResting(pen2);
  }
}
