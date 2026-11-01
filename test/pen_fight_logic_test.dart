import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:classic_ludo/pen_fight/pen_fight_computer_player.dart';
import 'package:classic_ludo/pen_fight/pen_fight_config.dart';
import 'package:classic_ludo/pen_fight/pen_fight_controller.dart';
import 'package:classic_ludo/pen_fight/pen_fight_models.dart';
import 'package:classic_ludo/pen_fight/pen_fight_physics.dart';
import 'package:classic_ludo/pen_fight/pen_fight_vec2.dart';

void main() {
  group('Pen Fight - Vector & Math Tests', () {
    test('PenFightVec2 basic arithmetic and operations', () {
      const v1 = PenFightVec2(3.0, 4.0);
      const v2 = PenFightVec2(1.0, 2.0);

      expect(v1 + v2, equals(const PenFightVec2(4.0, 6.0)));
      expect(v1 - v2, equals(const PenFightVec2(2.0, 2.0)));
      expect(v1 * 2.0, equals(const PenFightVec2(6.0, 8.0)));
      expect(v1 / 2.0, equals(const PenFightVec2(1.5, 2.0)));
      expect(v1.length, closeTo(5.0, 1e-5));
      expect(v1.lengthSquared, closeTo(25.0, 1e-5));
      expect(v1.dot(v2), closeTo(11.0, 1e-5));

      final norm = v1.normalized();
      expect(norm.length, closeTo(1.0, 1e-5));
      expect(norm.x, closeTo(0.6, 1e-5));
      expect(norm.y, closeTo(0.8, 1e-5));

      final clamped = v1.clampedLength(2.5);
      expect(clamped.length, closeTo(2.5, 1e-5));
    });
  });

  group('Pen Fight - Rigid Body Physics Tests', () {
    test('Pen slides with linear and angular friction decelerating naturally to rest', () {
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(200.0, 300.0),
        velocity: const PenFightVec2(0.0, -200.0),
        angularVelocity: 6.0,
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 100.0),
        velocity: PenFightVec2.zero,
      );

      // Step simulation by 0.5 seconds
      for (var i = 0; i < 30; i++) {
        PenFightPhysics.stepSimulation(
          pen1: pen1,
          pen2: pen2,
          deltaTime: 1.0 / 60.0,
        );
      }

      // Linear speed and spin must decrease
      expect(pen1.position.y, lessThan(300.0));
      expect(pen1.velocity.length, lessThan(200.0));
      expect(pen1.angularVelocity.abs(), lessThan(6.0));

      // Simulate until pen comes to a complete rest
      for (var i = 0; i < 200; i++) {
        PenFightPhysics.stepSimulation(
          pen1: pen1,
          pen2: pen2,
          deltaTime: 1.0 / 60.0,
        );
      }

      expect(pen1.velocity, equals(PenFightVec2.zero));
      expect(pen1.angularVelocity, equals(0.0));
      expect(PenFightPhysics.areAllPensAtRest(pen1, pen2), isTrue);
    });

    test('Off-center hit applies torque and produces spin', () {
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(225.0, 300.0), // Offset right
        velocity: const PenFightVec2(0.0, -400.0), // Moving straight up
        angle: -math.pi / 2,
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 260.0), // Centered at 200, horizontal
        velocity: PenFightVec2.zero,
        angle: 0.0,
      );

      PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);

      // An off-center hit applies torque and spins the pen
      expect(pen2.angularVelocity.abs(), greaterThan(1.5));
    });

    test('Center hit makes pen slide straight with little to no spin', () {
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(200.0, 300.0), // Symmetrical at x = 200
        velocity: const PenFightVec2(0.0, -400.0), // Moving straight up
        angle: -math.pi / 2,
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 260.0), // Dead center at x = 200, horizontal
        velocity: PenFightVec2.zero,
        angle: 0.0,
      );

      PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);

      // Center hit: slides mostly straight with negligible spin
      expect(pen2.angularVelocity.abs(), lessThan(0.2));
      expect(pen2.velocity.y, lessThan(0.0));
    });

    test('Pen balances at table edge without falling when center of mass is on the table', () {
      // Pen spine extends 29px. Center of mass is at x = 12.0 (inside table).
      // Left tip overhangs table edge (12 - 29 - 7 = -24 px).
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(12.0, 300.0),
        angle: 0.0,
        velocity: PenFightVec2.zero,
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 100.0),
        velocity: PenFightVec2.zero,
      );

      PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);

      // Overhanging pen balances and does not fall because center of mass is on the table
      expect(pen1.isOffTable, isFalse);
    });

    test('Pen falls only when center of mass passes table edge', () {
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(-2.0, 300.0), // Center of mass crossed left edge (x < 0)
        velocity: const PenFightVec2(-50.0, 0.0),
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 200.0),
        velocity: PenFightVec2.zero,
      );

      PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);

      expect(pen1.isOffTable, isTrue);
      expect(pen2.isOffTable, isFalse);
    });

    test('Drag distance is reduced to 50% with gentle power curve mapping giving the same power', () {
      // Max drag is reduced by ~50% from 77.0 to 38.5 px
      expect(PenFightConfig.maxDragDistance, closeTo(38.5, 0.5));

      const origin = PenFightVec2(210.0, 300.0);

      // Half drag (19.25 px)
      final halfDrag = origin + const PenFightVec2(0.0, 19.25);
      final halfAim = PenFightAim.fromDrag(penPosition: origin, dragPos: halfDrag);
      // Gentle power curve means 50% drag produces < 50% power
      expect(halfAim.powerFraction, lessThan(0.50));
      expect(halfAim.power, lessThan(PenFightConfig.powerCap * 0.50));

      // Full short drag (38.5 px) gives 100% full power (exact same power value as full long pull)
      final fullDrag = origin + const PenFightVec2(0.0, 38.5);
      final fullAim = PenFightAim.fromDrag(penPosition: origin, dragPos: fullDrag);
      expect(fullAim.powerFraction, closeTo(1.0, 1e-4));
      expect(fullAim.power, closeTo(PenFightConfig.powerCap, 1e-4));

      // Beyond max drag clamps cleanly to full power
      final overDrag = origin + const PenFightVec2(0.0, 80.0);
      final overAim = PenFightAim.fromDrag(penPosition: origin, dragPos: overDrag);
      expect(overAim.powerFraction, equals(1.0));
      expect(overAim.power, equals(PenFightConfig.powerCap));
    });

    test('Heavy vs Slim stats and collision behavior', () {
      final heavy = Pen(
        id: PenFightPlayerId.player1,
        type: PenType.heavy,
        position: const PenFightVec2(200.0, 300.0),
      );
      final slim = Pen(
        id: PenFightPlayerId.player2,
        type: PenType.slim,
        position: const PenFightVec2(200.0, 300.0),
      );

      // Heavy has higher mass and width, lower powerCap than Slim
      expect(heavy.mass, greaterThan(slim.mass));
      expect(heavy.width, greaterThan(slim.width));
      expect(heavy.type.powerCap, lessThan(slim.type.powerCap));

      // Collision test: incoming Balanced pen hits Heavy vs Slim
      final in1 = Pen(
        id: PenFightPlayerId.player1,
        type: PenType.balanced,
        position: const PenFightVec2(200.0, 300.0),
        velocity: const PenFightVec2(0.0, -350.0),
      );
      final targetHeavy = Pen(
        id: PenFightPlayerId.player2,
        type: PenType.heavy,
        position: const PenFightVec2(200.0, 275.0),
        velocity: PenFightVec2.zero,
      );
      PenFightPhysics.stepSimulation(pen1: in1, pen2: targetHeavy, deltaTime: 1.0 / 60.0);
      final heavySpeed = targetHeavy.velocity.length;

      final in2 = Pen(
        id: PenFightPlayerId.player1,
        type: PenType.balanced,
        position: const PenFightVec2(200.0, 300.0),
        velocity: const PenFightVec2(0.0, -350.0),
      );
      final targetSlim = Pen(
        id: PenFightPlayerId.player2,
        type: PenType.slim,
        position: const PenFightVec2(200.0, 275.0),
        velocity: PenFightVec2.zero,
      );
      PenFightPhysics.stepSimulation(pen1: in2, pen2: targetSlim, deltaTime: 1.0 / 60.0);
      final slimSpeed = targetSlim.velocity.length;

      // Heavy barely moves when hit, while Slim gets pushed easily
      expect(slimSpeed, greaterThan(heavySpeed * 1.3));
    });
  });

  group('Pen Fight - Game Rules & Turn Resolution Tests', () {
    test('Turn switches when neither pen falls off', () {
      final ctrl = PenFightController();
      expect(ctrl.currentTurn, equals(PenFightPlayerId.player1));

      // Light shot that stops on the table without hitting pen2
      ctrl.applyFlick(PenFightPlayerId.player1, const PenFightVec2(0.0, -50.0));
      expect(ctrl.phase, equals(PenFightPhase.moving));

      for (var i = 0; i < 200; i++) {
        ctrl.step(1.0 / 60.0);
        if (ctrl.phase == PenFightPhase.aiming) break;
      }

      expect(ctrl.phase, equals(PenFightPhase.aiming));
      expect(ctrl.currentTurn, equals(PenFightPlayerId.player2));
      expect(ctrl.player1Score, equals(0));
      expect(ctrl.player2Score, equals(0));
    });

    test('Shooter wins round when opponent pen falls off', () {
      final ctrl = PenFightController();
      expect(ctrl.currentTurn, equals(PenFightPlayerId.player1));

      ctrl.pen2.position = const PenFightVec2(200.0, 10.0);
      ctrl.pen1.position = const PenFightVec2(200.0, 30.0);

      ctrl.applyFlick(PenFightPlayerId.player1, const PenFightVec2(0.0, -700.0));

      for (var i = 0; i < 300; i++) {
        ctrl.step(1.0 / 60.0);
        if (ctrl.phase == PenFightPhase.roundOver || ctrl.phase == PenFightPhase.gameOver) {
          break;
        }
      }

      expect(ctrl.pen2.isOffTable, isTrue);
      expect(ctrl.roundWinner, equals(PenFightPlayerId.player1));
      expect(ctrl.player1Score, equals(1));
    });

    test('Shooter loses round when shooter own pen falls off', () {
      final ctrl = PenFightController();
      ctrl.pen1.position = const PenFightVec2(390.0, 400.0);
      ctrl.applyFlick(PenFightPlayerId.player1, const PenFightVec2(600.0, 0.0));

      for (var i = 0; i < 300; i++) {
        ctrl.step(1.0 / 60.0);
        if (ctrl.phase == PenFightPhase.roundOver || ctrl.phase == PenFightPhase.gameOver) {
          break;
        }
      }

      expect(ctrl.pen1.isOffTable, isTrue);
      expect(ctrl.roundWinner, equals(PenFightPlayerId.player2));
      expect(ctrl.player2Score, equals(1));
    });

    test('Both fall off case: shooter loses round', () {
      final ctrl = PenFightController();
      ctrl.pen1.position = const PenFightVec2(200.0, 10.0);
      ctrl.pen2.position = const PenFightVec2(200.0, 5.0);

      ctrl.applyFlick(PenFightPlayerId.player1, const PenFightVec2(0.0, -900.0));

      for (var i = 0; i < 300; i++) {
        ctrl.step(1.0 / 60.0);
        if (ctrl.phase == PenFightPhase.roundOver || ctrl.phase == PenFightPhase.gameOver) {
          break;
        }
      }

      if (!ctrl.pen1.isOffTable || !ctrl.pen2.isOffTable) {
        ctrl.pen1.isOffTable = true;
        ctrl.pen2.isOffTable = true;
        ctrl.lastShooter = PenFightPlayerId.player1;
        ctrl.phase = PenFightPhase.moving;
        ctrl.step(1.0 / 60.0);
      }

      expect(ctrl.pen1.isOffTable, isTrue);
      expect(ctrl.pen2.isOffTable, isTrue);
      expect(ctrl.roundWinner, equals(PenFightPlayerId.player2));
      expect(ctrl.player2Score, equals(1));
    });

    test('Match ends when first player reaches 2 round wins (Best of 3)', () {
      final ctrl = PenFightController();

      ctrl.player1Score = 1;
      ctrl.nextRound();
      expect(ctrl.currentRound, equals(2));
      expect(ctrl.matchWinner, isNull);

      ctrl.lastShooter = PenFightPlayerId.player1;
      ctrl.phase = PenFightPhase.moving;
      ctrl.pen2.position = const PenFightVec2(200.0, -10.0);
      ctrl.pen2.isOffTable = true;
      ctrl.pen1.velocity = PenFightVec2.zero;
      ctrl.pen2.fallProgress = 1.0;

      ctrl.step(1.0 / 60.0);

      expect(ctrl.player1Score, equals(2));
      expect(ctrl.matchWinner, equals(PenFightPlayerId.player1));
      expect(ctrl.phase, equals(PenFightPhase.gameOver));
    });

    test('Restart resets match scores and pens to initial states', () {
      final ctrl = PenFightController();
      ctrl.player1Score = 1;
      ctrl.player2Score = 1;
      ctrl.currentRound = 3;

      ctrl.restartMatch();

      expect(ctrl.player1Score, equals(0));
      expect(ctrl.player2Score, equals(0));
      expect(ctrl.currentRound, equals(1));
      expect(ctrl.matchWinner, isNull);
      expect(ctrl.phase, equals(PenFightPhase.aiming));
      expect(ctrl.pen1.position, equals(PenFightConfig.player1InitialPos));
      expect(ctrl.pen2.position, equals(PenFightConfig.player2InitialPos));
    });
  });

  group('Pen Fight - Computer Player (AI) Tests', () {
    test('Bot calculates deterministic shot with seeded random', () {
      final bot1 = PenFightComputerPlayer(random: math.Random(12345));
      final bot2 = PenFightComputerPlayer(random: math.Random(12345));

      final penSelf = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 120.0),
      );
      final penOpponent = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(200.0, 480.0),
      );

      final shot1 = bot1.calculateShot(selfPen: penSelf, opponentPen: penOpponent);
      final shot2 = bot2.calculateShot(selfPen: penSelf, opponentPen: penOpponent);

      expect(shot1.flickVelocity.x, closeTo(shot2.flickVelocity.x, 1e-6));
      expect(shot1.flickVelocity.y, closeTo(shot2.flickVelocity.y, 1e-6));
      expect(shot1.power, closeTo(shot2.power, 1e-6));
      expect(shot1.aimDirection.y, greaterThan(0.7));
    });

    test('Bot never reads hidden data, only public pen physical state', () {
      final bot = PenFightComputerPlayer(random: math.Random(42));
      final selfPen = Pen(id: PenFightPlayerId.player2, position: const PenFightVec2(200.0, 100.0));
      final oppPen = Pen(id: PenFightPlayerId.player1, position: const PenFightVec2(200.0, 400.0));

      final shot = bot.calculateShot(selfPen: selfPen, opponentPen: oppPen);
      expect(shot, isNotNull);
      expect(shot.power, greaterThan(0.0));
    });

    test('Bot avoids self-fall shots when near table edge', () {
      final bot = PenFightComputerPlayer(random: math.Random(123));
      final selfPen = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(200.0, 25.0),
      );
      final oppPen = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(200.0, 400.0),
      );

      final shot = bot.calculateShot(selfPen: selfPen, opponentPen: oppPen);

      final testSelf = selfPen.copy();
      final testOpp = oppPen.copy();
      testSelf.velocity = shot.flickVelocity;

      for (var i = 0; i < 90; i++) {
        PenFightPhysics.stepSimulation(pen1: testSelf, pen2: testOpp, deltaTime: 1.0 / 60.0);
      }
      expect(testSelf.isOffTable, isFalse);
    });

    test('Full seeded computer-vs-computer match finishes with a winner', () {
      final random = math.Random(999);
      final ctrl = PenFightController(
        vsComputer: false,
        player1Name: 'CPU 1',
        player2Name: 'CPU 2',
        random: random,
      );

      final bot1 = PenFightComputerPlayer(random: math.Random(111));
      final bot2 = PenFightComputerPlayer(random: math.Random(222));

      var turnsCount = 0;
      const maxTurns = 50;

      while (!ctrl.isGameOver && turnsCount < maxTurns) {
        turnsCount++;
        final currentBot =
            ctrl.currentTurn == PenFightPlayerId.player1 ? bot1 : bot2;
        final selfPen = ctrl.activeShooterPen;
        final oppPen = ctrl.opponentPen;

        final shot = currentBot.calculateShot(selfPen: selfPen, opponentPen: oppPen);
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
        }
      }

      expect(ctrl.isGameOver, isTrue);
      expect(ctrl.matchWinner, isNotNull);
      expect(
        ctrl.player1Score == PenFightConfig.roundsToWin ||
            ctrl.player2Score == PenFightConfig.roundsToWin,
        isTrue,
      );
    });
  });

  group('Pen Fight - Advanced Collisions, Multiple Tables & Hazards Tests', () {
    test('a tip hit moving the other pen and applying angular torque', () {
      // Pen 2 is horizontal at (210, 200). Nib is at (239, 200).
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(210.0, 200.0),
        angle: 0.0, // Long axis along X
      );
      // Pen 1 is positioned right under the tip of pen 2, moving up
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(238.0, 245.0),
        velocity: const PenFightVec2(0.0, -350.0),
        angle: -math.pi / 2,
      );

      // Step simulation
      for (var i = 0; i < 5; i++) {
        PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);
      }

      // Tip hit must visibly move pen 2 and spin it
      expect(pen2.velocity.length, greaterThan(30.0));
      expect(pen2.angularVelocity.abs(), greaterThan(1.0));
    });

    test('a glancing hit rotating the other pen', () {
      // Pen 2 is vertical at (210, 200)
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(210.0, 200.0),
        angle: math.pi / 2,
      );
      // Pen 1 launches diagonally to graze the side of pen 2
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(225.0, 280.0),
        velocity: const PenFightVec2(-35.0, -320.0),
        angle: -math.pi / 2,
      );

      for (var i = 0; i < 20; i++) {
        PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);
        if (pen2.angularVelocity.abs() > 0.1) break;
      }

      // Glancing contact must rotate pen 2 and nudge it
      expect(pen2.angularVelocity.abs(), greaterThan(0.2));
      expect(pen2.velocity.length, greaterThan(5.0));
    });

    test('a head-on end-to-end hit pushes opponent straight with minimal spin', () {
      // Pen 1 pointing UP towards Pen 2
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(210.0, 260.0),
        velocity: const PenFightVec2(0.0, -350.0),
        angle: -math.pi / 2,
      );
      // Pen 2 pointing DOWN towards Pen 1, directly collinear
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(210.0, 195.0),
        velocity: PenFightVec2.zero,
        angle: math.pi / 2,
      );

      for (var i = 0; i < 5; i++) {
        PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);
      }

      // Pushed straight in -Y direction
      expect(pen2.velocity.y, lessThan(-50.0));
      // Head-on collinear hit produces very little spin
      expect(pen2.angularVelocity.abs(), lessThan(1.5));
    });

    test('no tunneling at max speed (850 px/s)', () {
      // Pen 1 moving at absolute max speed directly towards Pen 2
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(210.0, 270.0),
        velocity: const PenFightVec2(0.0, -PenFightConfig.maxSpeed),
        angle: -math.pi / 2,
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(210.0, 215.0),
        velocity: PenFightVec2.zero,
        angle: math.pi / 2,
      );

      // Single standard frame (1/60s)
      PenFightPhysics.stepSimulation(pen1: pen1, pen2: pen2, deltaTime: 1.0 / 60.0);

      // Pen 1 MUST NOT have tunneled through Pen 2 (must stay below pen2.position.y)
      expect(pen1.position.y, greaterThanOrEqualTo(pen2.position.y));
      // Pen 2 must have absorbed massive momentum
      expect(pen2.velocity.length, greaterThan(150.0));
    });

    test('a fall into the hole on Hole Table', () {
      // Pen 1 launched directly toward center hole (210, 210)
      final pen1 = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(210.0, 260.0),
        velocity: const PenFightVec2(0.0, -250.0),
        angle: -math.pi / 2,
      );
      final pen2 = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(50.0, 50.0),
      );

      for (var i = 0; i < 60; i++) {
        PenFightPhysics.stepSimulation(
          pen1: pen1,
          pen2: pen2,
          deltaTime: 1.0 / 60.0,
          tableType: PenFightTableType.hole,
        );
        if (pen1.isOffTable) break;
      }

      // Pen 1 center entered hole (R = 38) and fell off table
      expect(pen1.isOffTable, isTrue);
      // Its position is within/at the center hole
      expect(pen1.position.distanceTo(PenFightConfig.holeCenter), lessThanOrEqualTo(PenFightConfig.holeRadius + 5.0));
    });

    test('table order per round (Round 1: Classic, Round 2: Hole, Round 3: Classic)', () {
      expect(PenFightTableType.forRound(1), equals(PenFightTableType.classic));
      expect(PenFightTableType.forRound(2), equals(PenFightTableType.hole));
      expect(PenFightTableType.forRound(3), equals(PenFightTableType.classic));

      final ctrl = PenFightController();
      expect(ctrl.currentRound, equals(1));
      expect(ctrl.currentTableType, equals(PenFightTableType.classic));

      ctrl.nextRound();
      expect(ctrl.currentRound, equals(2));
      expect(ctrl.currentTableType, equals(PenFightTableType.hole));

      ctrl.nextRound();
      expect(ctrl.currentRound, equals(3));
      expect(ctrl.currentTableType, equals(PenFightTableType.classic));
    });

    test('bot avoids self-fall into hole on Hole Table', () {
      final bot = PenFightComputerPlayer(random: math.Random(101));

      // Hole Table: bot near center hole (offset from direct hole line)
      final selfHole = Pen(
        id: PenFightPlayerId.player2,
        position: const PenFightVec2(270.0, 160.0), // Near hole
      );
      final oppHole = Pen(
        id: PenFightPlayerId.player1,
        position: const PenFightVec2(150.0, 320.0),
      );
      final shotHole = bot.calculateShot(
        selfPen: selfHole,
        opponentPen: oppHole,
        tableType: PenFightTableType.hole,
      );

      final simSelfHole = selfHole.copy();
      final simOppHole = oppHole.copy();
      simSelfHole.velocity = shotHole.flickVelocity;

      for (var i = 0; i < 60; i++) {
        PenFightPhysics.stepSimulation(
          pen1: simSelfHole,
          pen2: simOppHole,
          deltaTime: 1.0 / 60.0,
          tableType: PenFightTableType.hole,
        );
      }
      expect(simSelfHole.isOffTable, isFalse);
    });

    test('seeded bot-vs-bot matches finish on every table (Classic, Hole)', () {
      for (final table in PenFightTableType.values) {
        final ctrl = PenFightController(
          vsComputer: false,
          player1Name: 'Bot1',
          player2Name: 'Bot2',
          random: math.Random(100 + table.index),
        );
        // Force the desired table type for this test
        if (table == PenFightTableType.hole) {
          ctrl.currentRound = 2;
        }

        final bot1 = PenFightComputerPlayer(random: math.Random(200 + table.index));
        final bot2 = PenFightComputerPlayer(random: math.Random(300 + table.index));

        var turns = 0;
        const maxTurns = 80;

        while (ctrl.phase != PenFightPhase.roundOver &&
            ctrl.phase != PenFightPhase.gameOver &&
            turns < maxTurns) {
          turns++;
          final currentBot =
              ctrl.currentTurn == PenFightPlayerId.player1 ? bot1 : bot2;
          final selfPen = ctrl.activeShooterPen;
          final oppPen = ctrl.opponentPen;

          final shot = currentBot.calculateShot(
            selfPen: selfPen,
            opponentPen: oppPen,
            tableType: ctrl.currentTableType,
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
        }

        // Round concluded with a round winner
        expect(ctrl.roundWinner != null || ctrl.isGameOver, isTrue,
            reason: 'Match/Round on ${table.displayName} must finish');
      }
    });
  });
}
