import 'dart:math' as math;
import 'pen_fight_computer_player.dart';
import 'pen_fight_config.dart';
import 'pen_fight_models.dart';
import 'pen_fight_physics.dart';
import 'pen_fight_vec2.dart';

/// Pure Dart game controller and state manager for Pen Fight.
/// Has zero Flutter dependencies so all rules, physics, and bot logic
/// can be unit-tested cleanly in pure Dart.
class PenFightController {
  final bool vsComputer;
  final String player1Name;
  final String player2Name;
  final PenType p1Type;
  final PenType p2Type;
  final PenFightComputerPlayer bot;

  late Pen pen1;
  late Pen pen2;

  PenFightPlayerId currentTurn = PenFightPlayerId.player1;
  PenFightPlayerId? lastShooter;
  PenFightPhase phase = PenFightPhase.aiming;

  int player1Score = 0;
  int player2Score = 0;
  int currentRound = 1;

  PenFightTableType get currentTableType => PenFightTableType.forRound(currentRound);

  PenFightAim? currentAim;
  PenFightPlayerId? roundWinner;
  PenFightPlayerId? matchWinner;
  String statusMessage = "Player 1's Turn";

  double motionTimer = 0.0;

  PenFightController({
    this.vsComputer = false,
    this.player1Name = 'Player 1',
    String? player2Name,
    this.p1Type = PenType.balanced,
    this.p2Type = PenType.balanced,
    math.Random? random,
  })  : player2Name = player2Name ?? (vsComputer ? 'CPU' : 'Player 2'),
        bot = PenFightComputerPlayer(random: random) {
    _initPens();
  }

  void _initPens() {
    pen1 = Pen(
      id: PenFightPlayerId.player1,
      type: p1Type,
      position: PenFightConfig.player1InitialPos,
      angle: PenFightConfig.player1InitialAngle,
    );
    pen2 = Pen(
      id: PenFightPlayerId.player2,
      type: p2Type,
      position: PenFightConfig.player2InitialPos,
      angle: PenFightConfig.player2InitialAngle,
    );
    statusMessage = "$player1Name's Turn";
  }

  Pen get activeShooterPen =>
      currentTurn == PenFightPlayerId.player1 ? pen1 : pen2;

  Pen get opponentPen =>
      currentTurn == PenFightPlayerId.player1 ? pen2 : pen1;

  String get currentTurnPlayerName =>
      currentTurn == PenFightPlayerId.player1 ? player1Name : player2Name;

  bool get isCpuTurn => vsComputer && currentTurn == PenFightPlayerId.player2;

  bool get isGameOver => phase == PenFightPhase.gameOver;

  bool get isRoundOver => phase == PenFightPhase.roundOver;

  /// Returns true if human input is permitted right now.
  bool canHumanAim(PenFightPlayerId player) {
    if (phase != PenFightPhase.aiming) return false;
    if (currentTurn != player) return false;
    if (vsComputer && player == PenFightPlayerId.player2) return false;
    return true;
  }

  /// Begins aiming for the active player.
  void startAim(PenFightPlayerId player, PenFightVec2 touchPos) {
    if (!canHumanAim(player)) return;
    final pen = player == PenFightPlayerId.player1 ? pen1 : pen2;
    currentAim = PenFightAim.fromDrag(
      penPosition: pen.position,
      dragPos: touchPos,
      maxPower: pen.type.powerCap,
    );
  }

  /// Updates aim drag position.
  void updateAim(PenFightVec2 touchPos) {
    if (phase != PenFightPhase.aiming) return;
    if (currentAim == null) return;
    final pen = activeShooterPen;
    currentAim = PenFightAim.fromDrag(
      penPosition: currentAim!.origin,
      dragPos: touchPos,
      maxPower: pen.type.powerCap,
    );
  }

  /// Cancels aiming without shooting.
  void cancelAim() {
    if (phase != PenFightPhase.aiming) return;
    currentAim = null;
  }

  /// Releases the human flick shot.
  bool releaseFlick() {
    if (phase != PenFightPhase.aiming) return false;
    if (currentAim == null) return false;

    // Minimum flick power threshold to avoid accidental tap releases
    if (currentAim!.power < 25.0) {
      currentAim = null;
      return false;
    }

    final aim = currentAim!;
    currentAim = null;
    applyFlick(currentTurn, aim.flickVelocity);
    return true;
  }

  /// Sets aim directly (used by CPU display).
  void setAim(PenFightAim aim) {
    currentAim = aim;
  }

  /// Applies a flick impulse to the shooter's pen.
  void applyFlick(PenFightPlayerId shooter, PenFightVec2 velocity) {
    if (phase != PenFightPhase.aiming) return;
    if (velocity.lengthSquared == 0.0) return;

    lastShooter = shooter;
    phase = PenFightPhase.moving;
    motionTimer = 0.0;
    currentAim = null;

    final pen = shooter == PenFightPlayerId.player1 ? pen1 : pen2;
    pen.velocity = velocity.clampedLength(PenFightConfig.maxSpeed);
    pen.angularVelocity = 0.0; // Starts with clean forward flick
    pen.angle = math.atan2(velocity.y, velocity.x);

    final shooterName = shooter == PenFightPlayerId.player1 ? player1Name : player2Name;
    statusMessage = '$shooterName shoots!';
  }

  /// Steps physics forward by [dt] seconds and checks for round/turn completion.
  void step(double dt) {
    if (phase != PenFightPhase.moving && phase != PenFightPhase.falling) {
      return;
    }

    motionTimer += dt;
    PenFightPhysics.stepSimulation(
      pen1: pen1,
      pen2: pen2,
      deltaTime: dt,
      tableType: currentTableType,
    );

    if (pen1.isOffTable || pen2.isOffTable) {
      phase = PenFightPhase.falling;
    }

    final atRest = PenFightPhysics.areAllPensAtRest(pen1, pen2);
    final timedOut = motionTimer >= PenFightConfig.maxMotionTime;

    if (atRest || timedOut) {
      if (timedOut) {
        // Enforce complete stop when maximum motion time is reached
        if (!pen1.isOffTable) {
          pen1.velocity = PenFightVec2.zero;
          pen1.angularVelocity = 0.0;
        }
        if (!pen2.isOffTable) {
          pen2.velocity = PenFightVec2.zero;
          pen2.angularVelocity = 0.0;
        }
      }
      _resolveTurnAndRound();
    }
  }

  /// Resolves turn outcomes and round results.
  ///
  /// Rules:
  /// - If opponent's pen falls off: shooter wins the round.
  /// - If shooter's own pen falls off: shooter loses the round (opponent wins).
  /// - If both fall off: shooter loses the round (opponent wins).
  /// - If neither falls off: turn passes to the next player.
  /// - Best of 3: first to 2 round wins wins the match.
  void _resolveTurnAndRound() {
    final p1Fell = pen1.isOffTable;
    final p2Fell = pen2.isOffTable;
    final shooter = lastShooter ?? currentTurn;
    final opponent = shooter.other;

    if (p1Fell || p2Fell) {
      // Determine round winner according to explicit rules
      PenFightPlayerId winner;
      final shooterFell = (shooter == PenFightPlayerId.player1 && p1Fell) ||
          (shooter == PenFightPlayerId.player2 && p2Fell);
      final opponentFell = (opponent == PenFightPlayerId.player1 && p1Fell) ||
          (opponent == PenFightPlayerId.player2 && p2Fell);

      if (shooterFell && opponentFell) {
        // "If both fall off, the shooter loses."
        winner = opponent;
      } else if (shooterFell) {
        // "If the shooter's own pen falls off, the shooter loses the round."
        winner = opponent;
      } else {
        // "if the opponent's pen falls off, the shooter wins the round."
        winner = shooter;
      }

      roundWinner = winner;
      if (winner == PenFightPlayerId.player1) {
        player1Score++;
      } else {
        player2Score++;
      }

      final winnerName = winner == PenFightPlayerId.player1 ? player1Name : player2Name;

      // Check match victory (Best of 3 -> first to 2)
      if (player1Score >= PenFightConfig.roundsToWin ||
          player2Score >= PenFightConfig.roundsToWin) {
        matchWinner = winner;
        phase = PenFightPhase.gameOver;
        statusMessage = '$winnerName wins the Match!';
      } else {
        phase = PenFightPhase.roundOver;
        statusMessage = '$winnerName wins Round $currentRound!';
      }
    } else {
      // Neither fell off -> switch turn
      currentTurn = currentTurn.other;
      phase = PenFightPhase.aiming;
      statusMessage = "$currentTurnPlayerName's Turn";
    }
  }

  /// Resets pens to initial tabletop positions for the next round.
  void nextRound() {
    if (matchWinner != null) return;
    currentRound++;
    roundWinner = null;
    currentAim = null;
    phase = PenFightPhase.aiming;
    motionTimer = 0.0;

    pen1.reset(
      newPosition: PenFightConfig.player1InitialPos,
      newAngle: PenFightConfig.player1InitialAngle,
      newType: p1Type,
    );
    pen2.reset(
      newPosition: PenFightConfig.player2InitialPos,
      newAngle: PenFightConfig.player2InitialAngle,
      newType: p2Type,
    );

    statusMessage = "Round $currentRound · $currentTurnPlayerName's Turn";
  }

  /// Restarts the entire match from round 1.
  void restartMatch() {
    player1Score = 0;
    player2Score = 0;
    currentRound = 1;
    currentTurn = PenFightPlayerId.player1;
    lastShooter = null;
    roundWinner = null;
    matchWinner = null;
    currentAim = null;
    phase = PenFightPhase.aiming;
    motionTimer = 0.0;

    pen1.reset(
      newPosition: PenFightConfig.player1InitialPos,
      newAngle: PenFightConfig.player1InitialAngle,
      newType: p1Type,
    );
    pen2.reset(
      newPosition: PenFightConfig.player2InitialPos,
      newAngle: PenFightConfig.player2InitialAngle,
      newType: p2Type,
    );

    statusMessage = "$player1Name's Turn";
  }

  /// Computes CPU shot for the computer player.
  PenFightAim computeCpuShot() {
    return bot.calculateShot(
      selfPen: pen2,
      opponentPen: pen1,
      tableType: currentTableType,
    );
  }
}
