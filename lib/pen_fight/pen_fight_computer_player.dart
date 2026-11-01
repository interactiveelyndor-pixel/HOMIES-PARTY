import 'dart:math' as math;
import 'pen_fight_config.dart';
import 'pen_fight_models.dart';
import 'pen_fight_physics.dart';
import 'pen_fight_vec2.dart';

class _ShotCandidate {
  final PenFightVec2 direction;
  final double power;
  double score = 0.0;

  _ShotCandidate({
    required this.direction,
    required this.power,
  });
}

/// Pure Dart fair, smart computer AI player for Pen Fight.
/// Has zero Flutter dependencies and never reads hidden information.
/// Uses the exact same physics engine, collision model, and shot method that a human uses.
///
/// Features:
/// - Evaluates candidate shots (direct hits, offset spin hits, edge-pushing, safe repositioning)
/// - Simulates candidates forward using [PenFightPhysics.stepSimulation]
/// - Scores outcomes: opponent falling is huge win, self falling is fatal, edge distance scored
/// - Incorporates human-like aim error, power error, and mistake chance from seeded random
class PenFightComputerPlayer {
  final math.Random _random;

  PenFightComputerPlayer({math.Random? random})
      : _random = random ?? math.Random();

  /// Calculates a fair, realistic shot for the computer player.
  PenFightAim calculateShot({
    required Pen selfPen,
    required Pen opponentPen,
    PenFightTableType tableType = PenFightTableType.classic,
  }) {
    final selfPos = selfPen.position;
    final maxPower = selfPen.type.powerCap;

    // 1. Generate candidate shots (including table-specific tactical shots)
    final candidates = _generateCandidates(
      selfPen: selfPen,
      opponentPen: opponentPen,
      maxPower: maxPower,
      tableType: tableType,
    );

    // 2. Simulate each candidate and compute score
    for (final candidate in candidates) {
      candidate.score = _evaluateCandidate(
        selfPen: selfPen,
        opponentPen: opponentPen,
        candidate: candidate,
        tableType: tableType,
      );
    }

    // Sort candidates descending by score
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 3. Fallible human-like selection (about 15% chance to choose a weaker or less accurate shot)
    _ShotCandidate selected;
    // Filter candidates to only those that do NOT result in self falling off
    final safeCandidates = candidates.where((c) => c.score > -10000.0).toList();
    final candidatePool = safeCandidates.isNotEmpty ? safeCandidates : candidates;

    if (candidatePool.length > 3 && _random.nextDouble() < PenFightConfig.botMistakeChance) {
      // Pick a weaker or less accurate candidate from middle/lower tier of safe candidates
      final mistakeIndex = candidatePool.length ~/ 2 + _random.nextInt(candidatePool.length ~/ 3);
      final candidate = candidatePool[math.min(mistakeIndex, candidatePool.length - 1)];
      selected = _ShotCandidate(
        direction: candidate.direction,
        power: candidate.power * 0.75,
      );
    } else {
      selected = candidatePool.first;
    }

    // 4. Apply human-like aim and power noise from seeded random
    final baseAngle = math.atan2(selected.direction.y, selected.direction.x);
    final aimNoise = (_random.nextDouble() * 2.0 - 1.0) * PenFightConfig.botError;
    final finalAngle = baseAngle + aimNoise;
    final finalDirection = PenFightVec2(math.cos(finalAngle), math.sin(finalAngle));

    final powerNoiseFactor =
        1.0 + (_random.nextDouble() * 2.0 - 1.0) * PenFightConfig.botPowerError;
    final noisyPower = (selected.power * powerNoiseFactor).clamp(60.0, maxPower);

    // Verify that human aim noise does not push a safe shot into a fatal hazard
    if (selected.score > -10000.0) {
      final verifySelf = selfPen.copy();
      final verifyOpp = opponentPen.copy();
      verifySelf.velocity = finalDirection * noisyPower;
      for (var i = 0; i < 70; i++) {
        PenFightPhysics.stepSimulation(
          pen1: verifySelf,
          pen2: verifyOpp,
          deltaTime: 1.0 / 60.0,
          tableType: tableType,
        );
        if (verifySelf.isOffTable) break;
      }
      if (verifySelf.isOffTable) {
        // If noise pushed the shot toward a hazard, soften the flick power like a hesitant human
        final softenedPower = (noisyPower * 0.65).clamp(60.0, maxPower);
        return PenFightAim.fromDirectionAndPower(
          penPosition: selfPos,
          direction: finalDirection,
          power: softenedPower,
          maxPower: maxPower,
        );
      }
    }

    return PenFightAim.fromDirectionAndPower(
      penPosition: selfPos,
      direction: finalDirection,
      power: noisyPower,
      maxPower: maxPower,
    );
  }

  List<_ShotCandidate> _generateCandidates({
    required Pen selfPen,
    required Pen opponentPen,
    required double maxPower,
    required PenFightTableType tableType,
  }) {
    final selfPos = selfPen.position;
    final oppPos = opponentPen.position;
    final oppSpineA = opponentPen.spinePointA;
    final oppSpineB = opponentPen.spinePointB;

    final candidates = <_ShotCandidate>[];

    // Angle to opponent center
    final deltaCenter = oppPos - selfPos;
    final baseAngle = math.atan2(deltaCenter.y, deltaCenter.x);

    // Angle to spine endpoints (off-center spin shots)
    final deltaA = oppSpineA - selfPos;
    final angleA = math.atan2(deltaA.y, deltaA.x);
    final deltaB = oppSpineB - selfPos;
    final angleB = math.atan2(deltaB.y, deltaB.x);

    // 1. Center shots with varying powers
    for (final frac in [0.55, 0.75, 0.95]) {
      candidates.add(_ShotCandidate(
        direction: PenFightVec2(math.cos(baseAngle), math.sin(baseAngle)),
        power: maxPower * frac,
      ));
    }

    // 2. Off-center spin shots aimed at endpoints
    for (final frac in [0.65, 0.85, 1.0]) {
      candidates.add(_ShotCandidate(
        direction: PenFightVec2(math.cos(angleA), math.sin(angleA)),
        power: maxPower * frac,
      ));
      candidates.add(_ShotCandidate(
        direction: PenFightVec2(math.cos(angleB), math.sin(angleB)),
        power: maxPower * frac,
      ));
    }

    // 3. Edge-pushing angles: offset slightly to push opponent toward nearest edge
    final oppDistLeft = oppPos.x;
    final oppDistRight = PenFightConfig.tableWidth - oppPos.x;
    final oppDistTop = oppPos.y;
    final oppDistBottom = PenFightConfig.tableHeight - oppPos.y;
    final minOppEdgeDist = math.min(
      math.min(oppDistLeft, oppDistRight),
      math.min(oppDistTop, oppDistBottom),
    );

    // Bias angle toward the side that pushes opponent toward nearest edge
    double edgeBiasOffset = 0.12;
    if (minOppEdgeDist == oppDistLeft) {
      edgeBiasOffset = deltaCenter.y >= 0 ? 0.12 : -0.12;
    } else if (minOppEdgeDist == oppDistRight) {
      edgeBiasOffset = deltaCenter.y >= 0 ? -0.12 : 0.12;
    }

    candidates.add(_ShotCandidate(
      direction: PenFightVec2(
        math.cos(baseAngle + edgeBiasOffset),
        math.sin(baseAngle + edgeBiasOffset),
      ),
      power: maxPower * 0.90,
    ));
    candidates.add(_ShotCandidate(
      direction: PenFightVec2(
        math.cos(baseAngle - edgeBiasOffset),
        math.sin(baseAngle - edgeBiasOffset),
      ),
      power: maxPower * 0.90,
    ));

    // 4. Safe repositioning shots: if self is in danger near an edge or hazard
    final selfDistLeft = selfPos.x;
    final selfDistRight = PenFightConfig.tableWidth - selfPos.x;
    final selfDistTop = selfPos.y;
    final selfDistBottom = PenFightConfig.tableHeight - selfPos.y;
    final minSelfEdgeDist = math.min(
      math.min(selfDistLeft, selfDistRight),
      math.min(selfDistTop, selfDistBottom),
    );

    if (minSelfEdgeDist < PenFightConfig.botEdgeDangerThreshold) {
      // Inward angle toward tabletop center
      final toCenter = const PenFightVec2(
            PenFightConfig.tableWidth / 2.0,
            PenFightConfig.tableHeight / 2.0,
          ) -
          selfPos;
      final centerAngle = math.atan2(toCenter.y, toCenter.x);

      candidates.add(_ShotCandidate(
        direction: PenFightVec2(math.cos(centerAngle), math.sin(centerAngle)),
        power: maxPower * 0.38,
      ));
      candidates.add(_ShotCandidate(
        direction: PenFightVec2(math.cos(centerAngle), math.sin(centerAngle)),
        power: maxPower * 0.55,
      ));
    }

    // Hazard safe repositioning when near or aiming through the center hole
    if (tableType == PenFightTableType.hole) {
      final toHole = PenFightConfig.holeCenter - selfPos;
      final angleToHole = math.atan2(toHole.y, toHole.x);
      final distToHole = toHole.length;
      final distToOpp = deltaCenter.length;

      // If hole is between self and opponent, add flanking candidates around it
      if (distToHole < distToOpp && (baseAngle - angleToHole).abs() < 0.65) {
        for (final offset in [-0.44, 0.44, -0.58, 0.58]) {
          final ang = baseAngle + offset;
          for (final frac in [0.65, 0.88, 1.0]) {
            candidates.add(_ShotCandidate(
              direction: PenFightVec2(math.cos(ang), math.sin(ang)),
              power: maxPower * frac,
            ));
          }
        }
      }

      if (distToHole < 140.0) {
        final awayAngle = math.atan2(-toHole.y, -toHole.x);
        for (final offset in [-1.2, 1.2, -1.57, 1.57, -0.8, 0.8]) {
          final ang = awayAngle + offset;
          candidates.add(_ShotCandidate(
            direction: PenFightVec2(math.cos(ang), math.sin(ang)),
            power: maxPower * 0.40,
          ));
        }
      }
    }

    // 5. Table hazard specific tactical candidate shots:
    if (tableType == PenFightTableType.hole) {
      final oppToHole = PenFightConfig.holeCenter - oppPos;
      if (oppToHole.length > 5.0) {
        final holeDir = oppToHole.normalized();
        final ghostContact = oppPos - holeDir * (opponentPen.radius + selfPen.radius * 0.8);
        final toGhost = ghostContact - selfPos;
        final angleToGhost = math.atan2(toGhost.y, toGhost.x);
        for (final frac in [0.70, 0.90, 1.0]) {
          candidates.add(_ShotCandidate(
            direction: PenFightVec2(math.cos(angleToGhost), math.sin(angleToGhost)),
            power: maxPower * frac,
          ));
        }
      }
    }

    return candidates;
  }

  double _evaluateCandidate({
    required Pen selfPen,
    required Pen opponentPen,
    required _ShotCandidate candidate,
    required PenFightTableType tableType,
  }) {
    // Clone both pens for forward simulation
    final simSelf = selfPen.copy();
    final simOpp = opponentPen.copy();

    // Apply candidate flick impulse
    simSelf.velocity = candidate.direction * candidate.power;
    simSelf.velocity = simSelf.velocity.clampedLength(PenFightConfig.maxSpeed);

    const simDt = 1.0 / 60.0;
    final steps = PenFightConfig.botSimEvaluationSteps;

    // Simulate physics forward with the current table's boundaries & hazards
    for (var i = 0; i < steps; i++) {
      PenFightPhysics.stepSimulation(
        pen1: simSelf,
        pen2: simOpp,
        deltaTime: simDt,
        tableType: tableType,
      );

      if (PenFightPhysics.areAllPensAtRest(simSelf, simOpp)) {
        break;
      }
    }

    // Scoring logic:
    // 1. Self falling off is fatal
    if (simSelf.isOffTable) {
      return -50000.0;
    }

    // 2. Opponent falling off is victory
    if (simOpp.isOffTable) {
      var score = 25000.0;
      // Deduct slightly if self ended near an edge
      final selfEdgeDist = _minEdgeDistance(simSelf.position);
      if (selfEdgeDist < PenFightConfig.botEdgeDangerThreshold) {
        score -= (PenFightConfig.botEdgeDangerThreshold - selfEdgeDist) * 50.0;
      }
      return score;
    }

    // 3. Both pens safe on tabletop: score based on positional tactical advantage
    var score = 0.0;

    if (tableType == PenFightTableType.hole) {
      // Opponent closer to hole is good
      final oppHoleDist = (simOpp.position - PenFightConfig.holeCenter).length;
      score += (PenFightConfig.tableWidth / 2.0 - oppHoleDist) * 20.0;

      // Self closer to hole is DANGEROUS: penalize heavily
      final selfHoleDist = (simSelf.position - PenFightConfig.holeCenter).length;
      if (selfHoleDist < PenFightConfig.botHoleDangerThreshold) {
        score -= (PenFightConfig.botHoleDangerThreshold - selfHoleDist) * 35.0;
      }
    } else {
      // Classic: open edges
      final oppEdgeDist = _minEdgeDistance(simOpp.position);
      score += (PenFightConfig.tableWidth / 2.0 - oppEdgeDist) * 16.0;

      final selfEdgeDist = _minEdgeDistance(simSelf.position);
      if (selfEdgeDist < PenFightConfig.botEdgeDangerThreshold) {
        score -= (PenFightConfig.botEdgeDangerThreshold - selfEdgeDist) * 22.0;
      }
    }

    // Power economy: slight preference for not using max power if outcome is similar
    score -= (candidate.power / selfPen.type.powerCap) * 6.0;

    return score;
  }

  static double _minEdgeDistance(PenFightVec2 pos) {
    final dL = pos.x;
    final dR = PenFightConfig.tableWidth - pos.x;
    final dT = pos.y;
    final dB = PenFightConfig.tableHeight - pos.y;
    return math.min(math.min(dL, dR), math.min(dT, dB));
  }
}
