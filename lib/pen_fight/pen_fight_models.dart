import 'dart:math' as math;
import 'pen_fight_config.dart';
import 'pen_fight_vec2.dart';

/// Identifier for players in Pen Fight.
enum PenFightPlayerId {
  player1,
  player2;

  PenFightPlayerId get other =>
      this == PenFightPlayerId.player1 ? PenFightPlayerId.player2 : PenFightPlayerId.player1;

  String get defaultLabel => this == PenFightPlayerId.player1 ? 'Player 1' : 'Player 2';
}

/// High-level game phase for turn and input management.
enum PenFightPhase {
  /// Waiting for human or bot input to aim and flick.
  aiming,

  /// Pens are sliding and colliding on the tabletop.
  moving,

  /// One or both pens have crossed the edge and are falling.
  falling,

  /// A round has concluded (best of 3 in progress).
  roundOver,

  /// The entire match has finished with a final winner.
  gameOver,
}

/// Available pen types with distinct rigid-body physical properties.
/// Stats only, no special abilities.
enum PenType {
  balanced,
  heavy,
  slim;

  String get displayName {
    switch (this) {
      case PenType.balanced:
        return 'Balanced';
      case PenType.heavy:
        return 'Heavy';
      case PenType.slim:
        return 'Slim';
    }
  }

  String get description {
    switch (this) {
      case PenType.balanced:
        return 'All-round stats · Steady control';
      case PenType.heavy:
        return 'Thick & high mass · Hard to push · Lower speed';
      case PenType.slim:
        return 'Thin & lightweight · High speed · Pushed easily';
    }
  }

  double get mass {
    switch (this) {
      case PenType.balanced:
        return PenFightConfig.balancedMass;
      case PenType.heavy:
        return PenFightConfig.heavyMass;
      case PenType.slim:
        return PenFightConfig.slimMass;
    }
  }

  double get length {
    switch (this) {
      case PenType.balanced:
        return PenFightConfig.balancedLength;
      case PenType.heavy:
        return PenFightConfig.heavyLength;
      case PenType.slim:
        return PenFightConfig.slimLength;
    }
  }

  double get width {
    switch (this) {
      case PenType.balanced:
        return PenFightConfig.balancedWidth;
      case PenType.heavy:
        return PenFightConfig.heavyWidth;
      case PenType.slim:
        return PenFightConfig.slimWidth;
    }
  }

  double get radius => width / 2.0;

  double get powerCap {
    switch (this) {
      case PenType.balanced:
        return PenFightConfig.balancedPowerCap;
      case PenType.heavy:
        return PenFightConfig.heavyPowerCap;
      case PenType.slim:
        return PenFightConfig.slimPowerCap;
    }
  }

  /// 2D Moment of Inertia for a cylinder / rod rotating around its center of mass:
  /// I = m * (length^2 + width^2) / 12.
  double get momentOfInertia => mass * (length * length + width * width) / 12.0;
}

/// Represents a single pen rigid-body on the tabletop.
class Pen {
  final PenFightPlayerId id;
  PenType type;
  PenFightVec2 position;
  PenFightVec2 velocity;
  double angle; // Orientation in radians
  double angularVelocity; // Spin rate in radians / second
  double radius;
  double length;
  double width;
  double mass;
  double momentOfInertia;
  bool isOffTable;
  double fallProgress; // 0.0 to 1.0 during falling animation

  Pen({
    required this.id,
    required this.position,
    PenType? type,
    PenFightVec2? velocity,
    double? angle,
    double? angularVelocity,
    double? radius,
    double? length,
    double? width,
    double? mass,
    double? momentOfInertia,
    this.isOffTable = false,
    this.fallProgress = 0.0,
  })  : type = type ?? PenType.balanced,
        velocity = velocity ?? PenFightVec2.zero,
        angularVelocity = angularVelocity ?? 0.0,
        angle = angle ??
            (id == PenFightPlayerId.player1
                ? PenFightConfig.player1InitialAngle
                : PenFightConfig.player2InitialAngle),
        radius = radius ?? (type?.radius ?? PenFightConfig.penRadius),
        length = length ?? (type?.length ?? PenFightConfig.penLength),
        width = width ?? (type?.width ?? PenFightConfig.penWidth),
        mass = mass ?? (type?.mass ?? PenFightConfig.penMass),
        momentOfInertia = momentOfInertia ??
            (type?.momentOfInertia ??
                (PenFightConfig.penMass *
                    (PenFightConfig.penLength * PenFightConfig.penLength +
                        PenFightConfig.penWidth * PenFightConfig.penWidth) /
                    12.0));

  /// Direction unit vector along the pen's main axis.
  PenFightVec2 get forward => PenFightVec2(math.cos(angle), math.sin(angle));

  /// Half-length of the inner spine segment.
  double get spineHalfLength => math.max(0.0, (length - width) / 2.0);

  /// Back spine endpoint (cap end).
  PenFightVec2 get spinePointA => position - (forward * spineHalfLength);

  /// Front spine endpoint (nib end).
  PenFightVec2 get spinePointB => position + (forward * spineHalfLength);

  Pen copy() => Pen(
        id: id,
        type: type,
        position: position,
        velocity: velocity,
        angle: angle,
        angularVelocity: angularVelocity,
        radius: radius,
        length: length,
        width: width,
        mass: mass,
        momentOfInertia: momentOfInertia,
        isOffTable: isOffTable,
        fallProgress: fallProgress,
      );

  void reset({
    required PenFightVec2 newPosition,
    required double newAngle,
    PenType? newType,
  }) {
    position = newPosition;
    velocity = PenFightVec2.zero;
    angle = newAngle;
    angularVelocity = 0.0;
    isOffTable = false;
    fallProgress = 0.0;

    if (newType != null) {
      type = newType;
      radius = newType.radius;
      length = newType.length;
      width = newType.width;
      mass = newType.mass;
      momentOfInertia = newType.momentOfInertia;
    }
  }
}

/// Represents the active aiming state during a drag gesture or bot calculation.
class PenFightAim {
  final PenFightVec2 origin;
  final PenFightVec2 dragCurrent;
  final PenFightVec2 aimDirection;
  final double power;
  final double powerFraction;

  const PenFightAim({
    required this.origin,
    required this.dragCurrent,
    required this.aimDirection,
    required this.power,
    required this.powerFraction,
  });

  /// The resulting flick impulse velocity vector.
  PenFightVec2 get flickVelocity => aimDirection * power;

  /// Creates an aim state calculated by dragging backward from [penPosition].
  /// Uses reduced max drag distance and gentle power curve mapping.
  static PenFightAim fromDrag({
    required PenFightVec2 penPosition,
    required PenFightVec2 dragPos,
    double? maxPower,
  }) {
    final effectiveMaxPower = maxPower ?? PenFightConfig.powerCap;
    final dragVector = dragPos - penPosition;
    final dragDistance = dragVector.length;

    // Aim direction is opposite to the drag pull direction
    PenFightVec2 aimDir;
    if (dragDistance > 1.0) {
      aimDir = (-dragVector).normalized();
    } else {
      aimDir = const PenFightVec2(0.0, -1.0);
    }

    final clampedDrag = math.min(dragDistance, PenFightConfig.maxDragDistance);
    final rawFraction = (clampedDrag / PenFightConfig.maxDragDistance).clamp(0.0, 1.0);

    // Gentle power curve: softer touch on medium pull-backs
    final curvedFraction = math.pow(rawFraction, PenFightConfig.powerCurveExponent).toDouble();
    final power = (curvedFraction * effectiveMaxPower).clamp(0.0, effectiveMaxPower);

    return PenFightAim(
      origin: penPosition,
      dragCurrent: dragPos,
      aimDirection: aimDir,
      power: power,
      powerFraction: curvedFraction,
    );
  }

  /// Creates an aim state directly from an aim direction and power value (used by computer player).
  static PenFightAim fromDirectionAndPower({
    required PenFightVec2 penPosition,
    required PenFightVec2 direction,
    required double power,
    double? maxPower,
  }) {
    final effectiveMaxPower = maxPower ?? PenFightConfig.powerCap;
    final normDir = direction.normalized();
    final clampedPower = power.clamp(0.0, effectiveMaxPower);
    final fraction = effectiveMaxPower > 0.0 ? (clampedPower / effectiveMaxPower) : 0.0;

    // Visual drag current opposite to direction
    final dragCurrent =
        penPosition - (normDir * (fraction * PenFightConfig.maxDragDistance));

    return PenFightAim(
      origin: penPosition,
      dragCurrent: dragCurrent,
      aimDirection: normDir,
      power: clampedPower,
      powerFraction: fraction,
    );
  }
}

/// The tabletop arenas for Pen Fight, switching automatically per round.
/// - Round 1: Classic (Square table, all edges open)
/// - Round 2: Hole (Center round hole + open edges)
/// - Round 3: Classic (Square table, all edges open)
enum PenFightTableType {
  classic,
  hole;

  String get displayName {
    switch (this) {
      case PenFightTableType.classic:
        return 'Classic Table';
      case PenFightTableType.hole:
        return 'Hole Table';
    }
  }

  String get subtitle {
    switch (this) {
      case PenFightTableType.classic:
        return 'Square Arena · Open Edges';
      case PenFightTableType.hole:
        return 'Middle Hole Hazard · Open Edges';
    }
  }

  static PenFightTableType forRound(int round) {
    if (round == 2) return PenFightTableType.hole;
    return PenFightTableType.classic;
  }
}

