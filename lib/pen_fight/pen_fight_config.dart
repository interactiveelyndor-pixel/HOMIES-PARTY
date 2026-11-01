import 'dart:math' as math;
import 'pen_fight_vec2.dart';

/// Centralized configuration holding ALL tuning numbers, dimensions,
/// physics parameters, table configurations, and AI constants for Pen Fight.
/// Pure Dart with zero Flutter dependencies.
class PenFightConfig {
  PenFightConfig._();

  // --- Table Dimensions (Virtual Coordinate System: Square Table) ---
  /// Virtual width of the square tabletop.
  static const double tableWidth = 420.0;

  /// Virtual height of the square tabletop.
  static const double tableHeight = 420.0;

  /// Aspect ratio for square table (width / height = 420 / 420 = 1.0).
  static const double aspectRatio = 1.0;

  // --- Starting Positions & Angles ---
  static const PenFightVec2 player1InitialPos = PenFightVec2(210.0, 330.0);
  static const PenFightVec2 player2InitialPos = PenFightVec2(210.0, 90.0);
  static const double player1InitialAngle = -math.pi / 2;
  static const double player2InitialAngle = math.pi / 2;

  // --- Pen Type Specifications ---
  // Balanced Pen
  static const double balancedMass = 1.0;
  static const double balancedLength = 72.0;
  static const double balancedWidth = 14.0;
  static const double balancedRadius = balancedWidth / 2.0;
  static const double balancedPowerCap = 600.0;

  // Heavy Pen (thick, high mass, lower launch speed, barely moves when hit)
  static const double heavyMass = 1.36;
  static const double heavyLength = 74.0;
  static const double heavyWidth = 17.0;
  static const double heavyRadius = heavyWidth / 2.0;
  static const double heavyPowerCap = 540.0;

  // Slim Pen (thin, low mass, high launch speed, pushed easily)
  static const double slimMass = 0.76;
  static const double slimLength = 70.0;
  static const double slimWidth = 11.0;
  static const double slimRadius = slimWidth / 2.0;
  static const double slimPowerCap = 680.0;

  // Defaults (backward compatibility)
  static const double penRadius = balancedRadius;
  static const double penLength = balancedLength;
  static const double penWidth = balancedWidth;
  static const double penMass = balancedMass;
  static const double powerCap = balancedPowerCap;

  // --- Shorter Pull-Back & Balance Tuning ---
  /// Reduced max drag distance: ~50% of the previous 77.0px = 38.5 px.
  static const double maxDragDistance = 38.5;

  /// Exponent for gentle power curve: soft touch at low drag, smooth ramp-up.
  static const double powerCurveExponent = 1.25;

  /// Scale multiplier converting drag distance in virtual pixels to launch velocity.
  static const double dragToPowerRatio = powerCap / maxDragDistance;

  // --- Rigid Body Physics Tuning ---
  /// Linear surface sliding friction deceleration (pixels/s^2).
  static const double friction = 460.0;

  /// Angular friction deceleration (radians/s^2) so spin fades naturally.
  static const double angularFriction = 12.0;

  /// Viscous damping applied per second.
  static const double viscousDamping = 0.35;

  /// Angular viscous damping applied per second.
  static const double angularViscousDamping = 0.45;

  /// Coefficient of restitution (bounce) during pen-to-pen contact.
  static const double bounce = 0.72;

  /// Tangential Coulomb friction coefficient during pen-to-pen contact.
  static const double contactFriction = 0.25;

  /// Absolute maximum linear speed cap to prevent physics tunneling through objects.
  static const double maxSpeed = 850.0;

  /// Absolute maximum angular velocity cap (rad/s).
  static const double maxAngularSpeed = 26.0;

  /// Linear speed threshold below which a pen is considered to have stopped sliding.
  static const double stopThreshold = 10.0;

  /// Angular speed threshold below which a pen is considered to have stopped spinning.
  static const double angularStopThreshold = 0.25;

  /// Maximum allowed motion duration (in seconds) per shot before motion is safely forced to stop.
  static const double maxMotionTime = 3.5;

  /// Fixed physics integration timestep for deterministic simulation across all devices.
  static const double fixedTimestep = 1.0 / 60.0;

  /// Sub-steps per frame (10 sub-steps guarantee <= 1.4px movement per sub-step,
  /// far less than half the thinnest pen thickness of 5.5px, completely eliminating tunneling).
  static const int physicsSubSteps = 10;

  // --- Table Types & Geometric Features ---
  /// Center hole position for the Hole table.
  static const PenFightVec2 holeCenter = PenFightVec2(210.0, 210.0);

  /// Radius of the center hole.
  static const double holeRadius = 38.0;

  // --- Edge Balance & Overhanging Tuning ---
  /// Number of support sample points along pen spine to check table support.
  static const int spineSampleCount = 5;

  /// Overhang torque factor that pivots an overhanging pen around the table edge.
  static const double overhangTorqueFactor = 1.8;

  // --- Fair, Smart Bot (AI) Tuning ---
  /// Number of candidate shots the bot generates and simulates.
  static const int botCandidateCount = 18;

  /// Human-like random aim error range in radians (~23.0 degrees).
  static const double botError = 0.40;

  /// Human-like random power error fraction (~30%).
  static const double botPowerError = 0.30;

  /// Chance (about 32%) the bot selects a weaker or less accurate shot like a human.
  static const double botMistakeChance = 0.32;

  /// Edge distance below which the bot considers its position hazardous.
  static const double botEdgeDangerThreshold = 65.0;

  /// Danger threshold around center hole for bot hazard evaluation.
  static const double botHoleDangerThreshold = holeRadius + 40.0;

  /// Number of simulation steps used during AI candidate evaluation.
  static const int botSimEvaluationSteps = 60;

  /// Delay in milliseconds before the computer begins aiming after human turn ends.
  static const int botDelay = 800;

  /// Duration in milliseconds the computer displays its aim trajectory before shooting.
  static const int botAimDisplayMs = 400;

  // --- Match & Rule Settings ---
  /// Number of round wins required to win the match (Best of 3 -> first to 2).
  static const int roundsToWin = 2;

  /// Delay in milliseconds between rounds when resetting the table.
  static const int roundResetDelayMs = 1200;
}
