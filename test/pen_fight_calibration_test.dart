import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/pen_fight/pen_fight_computer_player.dart';
import 'package:classic_ludo/pen_fight/pen_fight_controller.dart';
import 'package:classic_ludo/pen_fight/pen_fight_models.dart';
import 'package:classic_ludo/pen_fight/pen_fight_vec2.dart';

/// Reference player: uses the same engine with a fixed human-like error
/// and a simple aim-at-the-opponent strategy (no edge planning or simulation).
class ReferencePlayer {
  final math.Random _random;

  ReferencePlayer({math.Random? random}) : _random = random ?? math.Random();

  PenFightAim calculateShot({
    required Pen selfPen,
    required Pen opponentPen,
    PenFightTableType tableType = PenFightTableType.classic,
  }) {
    final selfPos = selfPen.position;
    final oppPos = opponentPen.position;
    final delta = oppPos - selfPos;
    var baseAngle = math.atan2(delta.y, delta.x);

    var powerScale = 1.5;
    var basePowerAdd = 180.0;

    // Human-like obstacle & hazard awareness
    if (tableType == PenFightTableType.hole) {
      final holeCenter = const PenFightVec2(210.0, 210.0);
      final toHole = holeCenter - selfPos;
      final angleToHole = math.atan2(toHole.y, toHole.x);
      final distToOpp = delta.length;
      final oppToHole = holeCenter - oppPos;
      final oppHoleDist = oppToHole.length;

      bool hitsHole(double angle) {
        final dir = PenFightVec2(math.cos(angle), math.sin(angle));
        final proj = toHole.dot(dir).clamp(0.0, distToOpp);
        final closest = selfPos + dir * proj;
        return (holeCenter - closest).length < 48.0;
      }

      if (oppHoleDist < 160.0 && oppHoleDist > 5.0 && !hitsHole(baseAngle)) {
        final pushDir = oppToHole / oppHoleDist;
        final aimPoint = oppPos - pushDir * 20.0;
        final toAim = aimPoint - selfPos;
        final testAngle = math.atan2(toAim.y, toAim.x);
        if (!hitsHole(testAngle)) {
          baseAngle = testAngle;
          powerScale = 1.70;
          basePowerAdd = 200.0;
        } else {
          final flankDir = (baseAngle >= angleToHole) ? 1.0 : -1.0;
          baseAngle += flankDir * 0.48;
          powerScale = 1.05;
          basePowerAdd = 160.0;
        }
      } else if (hitsHole(baseAngle)) {
        final flankDir = (baseAngle >= angleToHole) ? 1.0 : -1.0;
        baseAngle += flankDir * 0.48;
        powerScale = 1.05;
        basePowerAdd = 160.0;
      } else {
        powerScale = 1.70;
        basePowerAdd = 200.0;
      }
    }

    // Fixed human-like error (~0.08 rad, ~4.5 degrees)
    final aimNoise = (_random.nextDouble() * 2.0 - 1.0) * 0.08;
    final finalAngle = baseAngle + aimNoise;
    final direction = PenFightVec2(math.cos(finalAngle), math.sin(finalAngle));

    // Simple distance-based flick power with small noise
    final distance = delta.length;
    var power = distance * powerScale + basePowerAdd;
    power *= 1.0 + (_random.nextDouble() * 2.0 - 1.0) * 0.08;

    final maxPower = selfPen.type.powerCap;
    final clampedPower = power.clamp(150.0, maxPower);

    return PenFightAim.fromDirectionAndPower(
      penPosition: selfPos,
      direction: direction,
      power: clampedPower,
      maxPower: maxPower,
    );
  }
}

void main() {
  test('Calibrate Bot Win Rate on Classic Table (100 seeded matches)', () {
    const matchCount = 100;
    var botWins = 0;

    for (var match = 0; match < matchCount; match++) {
      final matchRandom = math.Random(10000 + match);
      final refRandom = math.Random(20000 + match);
      final botRandom = math.Random(30000 + match);

      final bot = PenFightComputerPlayer(random: botRandom);
      final refPlayer = ReferencePlayer(random: refRandom);

      final botIsP1 = match % 2 == 1;
      final ctrl = PenFightController(
        vsComputer: false,
        player1Name: botIsP1 ? 'SmartBot' : 'RefPlayer',
        player2Name: botIsP1 ? 'RefPlayer' : 'SmartBot',
        p1Type: PenType.balanced,
        p2Type: PenType.balanced,
        random: matchRandom,
      );

      var turnCount = 0;
      const maxTurns = 80;

      while (!ctrl.isGameOver && turnCount < maxTurns) {
        turnCount++;
        final isBotTurn = (ctrl.currentTurn == PenFightPlayerId.player1) == botIsP1;
        final shot = isBotTurn
            ? bot.calculateShot(
                selfPen: ctrl.activeShooterPen,
                opponentPen: ctrl.opponentPen,
                tableType: PenFightTableType.classic,
              )
            : refPlayer.calculateShot(
                selfPen: ctrl.activeShooterPen,
                opponentPen: ctrl.opponentPen,
                tableType: PenFightTableType.classic,
              );

        ctrl.applyFlick(ctrl.currentTurn, shot.flickVelocity);

        for (var step = 0; step < 240; step++) {
          ctrl.step(1.0 / 60.0);
          if (ctrl.phase == PenFightPhase.roundOver ||
              ctrl.phase == PenFightPhase.gameOver ||
              ctrl.phase == PenFightPhase.aiming) {
            break;
          }
        }

        if (ctrl.phase == PenFightPhase.roundOver) {
          ctrl.nextRound();
          ctrl.currentRound = 1; // Keep on Classic Table for this test
        }
      }

      final winner = ctrl.matchWinner ??
          (ctrl.player2Score > ctrl.player1Score
              ? PenFightPlayerId.player2
              : PenFightPlayerId.player1);

      final botId = botIsP1 ? PenFightPlayerId.player1 : PenFightPlayerId.player2;
      if (winner == botId) {
        botWins++;
      }
    }

    final winRate = botWins / matchCount;
    // ignore: avoid_print
    print('CLASSIC TABLE BOT CALIBRATION: $botWins / $matchCount (${(winRate * 100).toStringAsFixed(1)}%)');
    expect(winRate, greaterThanOrEqualTo(0.40));
    expect(winRate, lessThanOrEqualTo(0.55));
  });

  test('Calibrate Bot Win Rate on Hole Table (100 seeded matches)', () {
    const matchCount = 100;
    var botWins = 0;

    for (var match = 0; match < matchCount; match++) {
      final matchRandom = math.Random(15000 + match);
      final refRandom = math.Random(25000 + match);
      final botRandom = math.Random(35000 + match);

      final bot = PenFightComputerPlayer(random: botRandom);
      final refPlayer = ReferencePlayer(random: refRandom);

      final botIsP1 = match % 2 == 1;
      final ctrl = PenFightController(
        vsComputer: false,
        player1Name: botIsP1 ? 'SmartBot' : 'RefPlayer',
        player2Name: botIsP1 ? 'RefPlayer' : 'SmartBot',
        p1Type: PenType.balanced,
        p2Type: PenType.balanced,
        random: matchRandom,
      );
      ctrl.currentRound = 2; // Hole Table

      var turnCount = 0;
      const maxTurns = 80;

      while (!ctrl.isGameOver && turnCount < maxTurns) {
        turnCount++;
        final isBotTurn = (ctrl.currentTurn == PenFightPlayerId.player1) == botIsP1;
        final shot = isBotTurn
            ? bot.calculateShot(
                selfPen: ctrl.activeShooterPen,
                opponentPen: ctrl.opponentPen,
                tableType: PenFightTableType.hole,
              )
            : refPlayer.calculateShot(
                selfPen: ctrl.activeShooterPen,
                opponentPen: ctrl.opponentPen,
                tableType: PenFightTableType.hole,
              );

        ctrl.applyFlick(ctrl.currentTurn, shot.flickVelocity);

        for (var step = 0; step < 240; step++) {
          ctrl.step(1.0 / 60.0);
          if (ctrl.phase == PenFightPhase.roundOver ||
              ctrl.phase == PenFightPhase.gameOver ||
              ctrl.phase == PenFightPhase.aiming) {
            break;
          }
        }

        if (ctrl.phase == PenFightPhase.roundOver) {
          ctrl.nextRound();
          ctrl.currentRound = 2; // Keep on Hole Table for this test
        }
      }

      final winner = ctrl.matchWinner ??
          (ctrl.player2Score > ctrl.player1Score
              ? PenFightPlayerId.player2
              : PenFightPlayerId.player1);

      final botId = botIsP1 ? PenFightPlayerId.player1 : PenFightPlayerId.player2;
      if (winner == botId) {
        botWins++;
      }
    }

    final winRate = botWins / matchCount;
    // ignore: avoid_print
    print('HOLE TABLE BOT CALIBRATION: $botWins / $matchCount (${(winRate * 100).toStringAsFixed(1)}%)');
    expect(winRate, greaterThanOrEqualTo(0.40));
    expect(winRate, lessThanOrEqualTo(0.55));
  });
}
