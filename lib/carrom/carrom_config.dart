import 'carrom_vec2.dart';

/// Centralized configuration holding ALL physics, dimension, and rule constants
/// for the Carrom game.
class CarromConfig {
  CarromConfig._();

  // --- Board Dimensions ---
  /// Virtual coordinate width and height of the Carrom board.
  static const double boardSize = 800.0;

  /// Inset of the wooden frame surrounding the playing area.
  static const double frameThickness = 48.0;

  /// Playable surface boundary limits.
  static const double playableMin = frameThickness;
  static const double playableMax = boardSize - frameThickness;

  /// Corner pockets.
  static const double pocketRadius = 34.0;
  static const double pocketInset = 76.0;

  static const List<CarromVec2> pocketCenters = [
    CarromVec2(pocketInset, pocketInset), // Top-Left
    CarromVec2(boardSize - pocketInset, pocketInset), // Top-Right
    CarromVec2(pocketInset, boardSize - pocketInset), // Bottom-Left
    CarromVec2(boardSize - pocketInset, boardSize - pocketInset), // Bottom-Right
  ];

  // --- Center Circle & Layout ---
  static const CarromVec2 centerPoint = CarromVec2(400.0, 400.0);
  static const double centerCircleRadius = 45.0;
  static const double centerOuterCircleRadius = 110.0;

  // --- Baselines ---
  /// Player 1 (White) baseline at bottom.
  static const double player1BaselineY = 640.0;

  /// Player 2 (Black) baseline at top.
  static const double player2BaselineY = 160.0;

  /// Baseline horizontal boundaries.
  static const double baselineMinX = 220.0;
  static const double baselineMaxX = 580.0;

  /// Circles at the ends of each baseline.
  static const double baselineCircleRadius = 24.0;

  // --- Radii and Masses ---
  static const double coinRadius = 15.0;
  static const double coinMass = 1.0;

  static const double strikerRadius = 21.0;
  static const double strikerMass = 3.0;

  // --- Physics Constants ---
  /// Dynamic friction deceleration (pixels/s^2) applied against velocity.
  static const double frictionDeceleration = 260.0;

  /// Drag multiplier applied per second (viscous damping).
  static const double viscousDamping = 0.15;

  /// Restitution (bounciness) for coin-to-coin collisions.
  static const double coinRestitution = 0.92;

  /// Restitution for striker-to-coin collisions.
  static const double strikerCoinRestitution = 0.90;

  /// Restitution for wall rebounds.
  static const double wallRestitution = 0.82;

  /// Maximum speed cap (pixels/second) to prevent physics tunneling.
  static const double maxVelocity = 1500.0;

  /// Velocity threshold below which a coin is considered at rest (pixels/second).
  static const double stopThreshold = 5.0;

  /// Fixed sub-step time for physics calculation (seconds).
  static const double fixedDeltaTime = 1.0 / 240.0;

  /// Number of physics sub-steps per 60Hz display frame (60 * 4 = 240Hz).
  static const int subStepsPerFrame = 4;

  /// Maximum time allowed for any single motion phase before forcing stop (seconds).
  static const double maxSimulationTimeSeconds = 6.0;

  // --- Shooting & Power ---
  /// Maximum pull distance for aiming gesture (virtual coordinates).
  static const double maxPullDistance = 140.0;

  /// Minimum pull distance required to register a shot.
  static const double minPullDistance = 12.0;

  /// Multiplier converting pull distance to impulse speed.
  static const double pullToVelocityScale = 10.0;

  /// Maximum initial shot speed for the striker.
  static const double maxShotSpeed = 1350.0;

  // --- Coin Quantities ---
  static const int whiteCoinsCount = 9;
  static const int blackCoinsCount = 9;

  // --- Scoring Points ---
  /// Points awarded for pocketing a black coin.
  static const int blackCoinPoints = 10;

  /// Points awarded for pocketing a white coin.
  static const int whiteCoinPoints = 20;

  /// Points awarded for pocketing and covering the Queen.
  static const int queenPoints = 50;

  // --- Computer Player ---
  /// Angular aim error (radians) added to each CPU shot — makes it beatable.
  static const double cpuAimErrorRadians = 0.07; // ≈ 4 degrees

  /// Milliseconds the CPU waits after pieces stop before shooting.
  static const int cpuShotDelayMs = 800;
}
