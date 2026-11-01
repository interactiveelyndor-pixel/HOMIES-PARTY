import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'carrom_colors.dart';
import 'carrom_config.dart';
import 'carrom_game_state.dart';
import 'carrom_models.dart';

/// CustomPainter rendering the classic wooden Carrom board, markings,
/// pockets, active coins, striker, and aiming line with power indicators.
class CarromBoardPainter extends CustomPainter {
  final CarromGameState state;

  CarromBoardPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    // Scale entire canvas from virtual 800x800 coordinate space to actual widget size
    final scale = size.width / CarromConfig.boardSize;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. Draw outer frame & playing surface
    _drawBoardSurface(canvas);

    // 2. Draw 4 corner pockets
    _drawPockets(canvas);

    // 3. Draw board markings (center circle, baselines, arrows)
    _drawMarkings(canvas);

    // 4. Draw active coins (White, Black, Queen)
    _drawCoins(canvas);

    // 5. Draw Striker
    _drawStriker(canvas);

    // 6. Draw Aiming trajectory & power indicator
    if (state.phase == CarromTurnPhase.aiming && state.dragAimVector != null) {
      _drawAimTrajectory(canvas);
    }

    canvas.restore();
  }

  void _drawBoardSurface(Canvas canvas) {
    const size = CarromConfig.boardSize;
    const frame = CarromConfig.frameThickness;

    // Outer wooden frame
    final framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          CarromColors.frameLight,
          CarromColors.frameDark,
          CarromColors.frameDark,
          CarromColors.frameBorder,
        ],
      ).createShader(const Rect.fromLTWH(0, 0, size, size));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, size, size),
        const Radius.circular(16),
      ),
      framePaint,
    );

    // Playing surface veneer
    final surfacePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          CarromColors.surfaceLight,
          CarromColors.surfaceDark,
          CarromColors.surfaceGrain,
        ],
      ).createShader(
        const Rect.fromLTWH(frame, frame, size - 2 * frame, size - 2 * frame),
      );

    canvas.drawRect(
      const Rect.fromLTWH(frame, frame, size - 2 * frame, size - 2 * frame),
      surfacePaint,
    );

    // Frame inner beveled shadow
    final innerBevelPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(
      const Rect.fromLTWH(frame, frame, size - 2 * frame, size - 2 * frame),
      innerBevelPaint,
    );
  }

  void _drawPockets(Canvas canvas) {
    for (final pocket in CarromConfig.pocketCenters) {
      // Dark pocket cavity
      final cavityPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            CarromColors.pocketCavity,
            Colors.black.withValues(alpha: 0.9),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(pocket.x, pocket.y),
            radius: CarromConfig.pocketRadius,
          ),
        );

      canvas.drawCircle(
        Offset(pocket.x, pocket.y),
        CarromConfig.pocketRadius,
        cavityPaint,
      );

      // Pocket rim outline
      final rimPaint = Paint()
        ..color = CarromColors.pocketRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(
        Offset(pocket.x, pocket.y),
        CarromConfig.pocketRadius,
        rimPaint,
      );

      // Pocket net cross-hatch hint
      final netPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final pOffset = Offset(pocket.x, pocket.y);
      canvas.drawLine(
        pOffset + const Offset(-14, -14),
        pOffset + const Offset(14, 14),
        netPaint,
      );
      canvas.drawLine(
        pOffset + const Offset(-14, 14),
        pOffset + const Offset(14, -14),
        netPaint,
      );
    }
  }

  void _drawMarkings(Canvas canvas) {
    final center = CarromConfig.centerPoint;
    final centerOffset = Offset(center.x, center.y);

    final linePaint = Paint()
      ..color = CarromColors.markingSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final redAccentPaint = Paint()
      ..color = CarromColors.markingPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Center Circles
    canvas.drawCircle(
      centerOffset,
      CarromConfig.centerCircleRadius,
      redAccentPaint,
    );
    canvas.drawCircle(
      centerOffset,
      CarromConfig.centerOuterCircleRadius,
      linePaint,
    );

    // Decorative Center Rosette
    for (var i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3);
      final petalCenter = Offset(
        center.x + 24.0 * math.cos(angle),
        center.y + 24.0 * math.sin(angle),
      );
      canvas.drawCircle(
        petalCenter,
        14.0,
        Paint()
          ..color = CarromColors.markingPrimary.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
    }

    // Red center Queen dot
    canvas.drawCircle(
      centerOffset,
      4.0,
      Paint()..color = CarromColors.markingAccent,
    );

    // --- Baselines ---
    _drawBaseline(
      canvas: canvas,
      y: CarromConfig.player1BaselineY,
      isBottom: true,
      linePaint: linePaint,
      redAccentPaint: redAccentPaint,
    );

    _drawBaseline(
      canvas: canvas,
      y: CarromConfig.player2BaselineY,
      isBottom: false,
      linePaint: linePaint,
      redAccentPaint: redAccentPaint,
    );

    // Diagonal corner arrows pointing to pockets
    _drawCornerArrows(canvas, linePaint);
  }

  void _drawBaseline({
    required Canvas canvas,
    required double y,
    required bool isBottom,
    required Paint linePaint,
    required Paint redAccentPaint,
  }) {
    const minX = CarromConfig.baselineMinX;
    const maxX = CarromConfig.baselineMaxX;
    const circleRadius = CarromConfig.baselineCircleRadius;
    final secondLineY = isBottom ? y - 18.0 : y + 18.0;

    // Double lines
    canvas.drawLine(Offset(minX, y), Offset(maxX, y), linePaint);
    canvas.drawLine(Offset(minX, secondLineY), Offset(maxX, secondLineY), linePaint);

    // End circles
    for (final x in [minX, maxX]) {
      final circleCenter = Offset(x, isBottom ? y - 9.0 : y + 9.0);

      // Outer circle
      canvas.drawCircle(circleCenter, circleRadius, linePaint);

      // Inner red spot
      canvas.drawCircle(
        circleCenter,
        circleRadius * 0.45,
        Paint()
          ..color = CarromColors.markingPrimary
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCornerArrows(Canvas canvas, Paint linePaint) {
    final arrowPaint = Paint()
      ..color = CarromColors.markingSecondary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 4 diagonal guidance lines pointing toward pockets
    const arrowPairs = [
      [Offset(200, 200), Offset(110, 110)], // Top-Left
      [Offset(600, 200), Offset(690, 110)], // Top-Right
      [Offset(200, 600), Offset(110, 690)], // Bottom-Left
      [Offset(600, 600), Offset(690, 690)], // Bottom-Right
    ];

    for (final pair in arrowPairs) {
      canvas.drawLine(pair[0], pair[1], arrowPaint);
      canvas.drawCircle(pair[0], 10.0, arrowPaint);
    }
  }

  void _drawCoins(Canvas canvas) {
    for (final coin in state.coins) {
      if (coin.isPocketed) continue;
      _drawSingleCoin(canvas, coin);
    }
  }

  void _drawSingleCoin(Canvas canvas, CarromCoin coin) {
    final offset = Offset(coin.position.x, coin.position.y);
    final r = coin.radius;

    // Coin Drop Shadow
    canvas.drawCircle(
      offset + const Offset(1.5, 2.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    if (coin.isQueen) {
      // --- Red Queen ---
      final queenShader = const RadialGradient(
        center: Alignment(-0.25, -0.3),
        colors: [
          CarromColors.queenRim,
          CarromColors.queenBase,
          CarromColors.queenShadow,
        ],
      ).createShader(Rect.fromCircle(center: offset, radius: r));

      canvas.drawCircle(offset, r, Paint()..shader = queenShader);

      // Gold center pip
      canvas.drawCircle(
        offset,
        r * 0.4,
        Paint()..color = CarromColors.queenGoldPip,
      );
      canvas.drawCircle(
        offset,
        r * 0.4,
        Paint()
          ..color = const Color(0xFFB8860B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      // Outer golden groove
      canvas.drawCircle(
        offset,
        r * 0.75,
        Paint()
          ..color = CarromColors.queenGoldPip.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    } else if (coin.isWhite) {
      // --- White / Ivory Coin ---
      final whiteShader = const RadialGradient(
        center: Alignment(-0.3, -0.35),
        colors: [
          CarromColors.whiteCoinBase,
          CarromColors.whiteCoinShadow,
          CarromColors.whiteCoinRim,
        ],
      ).createShader(Rect.fromCircle(center: offset, radius: r));

      canvas.drawCircle(offset, r, Paint()..shader = whiteShader);

      // Concentric groove
      canvas.drawCircle(
        offset,
        r * 0.65,
        Paint()
          ..color = CarromColors.whiteCoinRim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        offset,
        r * 0.25,
        Paint()
          ..color = CarromColors.whiteCoinRim
          ..style = PaintingStyle.fill,
      );
    } else {
      // --- Black / Dark Ebony Coin ---
      final blackShader = const RadialGradient(
        center: Alignment(-0.3, -0.35),
        colors: [
          CarromColors.blackCoinRim,
          CarromColors.blackCoinBase,
          CarromColors.blackCoinShadow,
        ],
      ).createShader(Rect.fromCircle(center: offset, radius: r));

      canvas.drawCircle(offset, r, Paint()..shader = blackShader);

      // Concentric groove & specular spot
      canvas.drawCircle(
        offset,
        r * 0.65,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        offset + Offset(-r * 0.25, -r * 0.25),
        r * 0.2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  void _drawStriker(Canvas canvas) {
    final striker = state.striker;
    if (striker.isPocketed) return;

    final offset = Offset(striker.position.x, striker.position.y);
    final r = striker.radius;

    // Striker Drop Shadow
    canvas.drawCircle(
      offset + const Offset(2.0, 3.5),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );

    // Striker Pearl Body
    final strikerShader = const RadialGradient(
      center: Alignment(-0.25, -0.25),
      colors: [
        CarromColors.strikerBase,
        CarromColors.strikerShadow,
        CarromColors.strikerRim,
      ],
    ).createShader(Rect.fromCircle(center: offset, radius: r));

    canvas.drawCircle(offset, r, Paint()..shader = strikerShader);

    // Metallic Outer Rim
    canvas.drawCircle(
      offset,
      r - 0.7,
      Paint()
        ..color = CarromColors.strikerRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner Grip Grooves
    canvas.drawCircle(
      offset,
      r * 0.72,
      Paint()
        ..color = CarromColors.strikerAccent.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Center Cyan Pip
    canvas.drawCircle(
      offset,
      r * 0.35,
      Paint()
        ..color = CarromColors.strikerAccent
        ..style = PaintingStyle.fill,
    );

    // Center Dot
    canvas.drawCircle(
      offset,
      2.5,
      Paint()..color = Colors.white,
    );

    // Active positioning glow
    if (state.phase == CarromTurnPhase.positioningStriker) {
      canvas.drawCircle(
        offset,
        r + 3.0,
        Paint()
          ..color = CarromColors.activeGlow.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawAimTrajectory(Canvas canvas) {
    final strikerPos = state.striker.position;
    final aimVec = state.dragAimVector;
    if (aimVec == null) return;

    final power = state.aimPower;
    final shotDir = aimVec.normalized();
    final start = Offset(strikerPos.x, strikerPos.y);

    // Trajectory length proportional to power
    final lineLength = 50.0 + power * 240.0;
    final end = start + Offset(shotDir.x * lineLength, shotDir.y * lineLength);

    // Choose color based on power tier
    final Color powerColor = power < 0.4
        ? CarromColors.powerLow
        : (power < 0.75 ? CarromColors.powerMed : CarromColors.powerHigh);

    // 1. Dotted trajectory line
    final linePaint = Paint()
      ..color = powerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    _drawDashedLine(canvas, start, end, linePaint);

    // 2. Arrowhead at tip
    final arrowAngle = math.atan2(shotDir.y, shotDir.x);
    const arrowLen = 14.0;
    const arrowSpread = 0.45;

    final arrowP1 = end - Offset(
      arrowLen * math.cos(arrowAngle - arrowSpread),
      arrowLen * math.sin(arrowAngle - arrowSpread),
    );
    final arrowP2 = end - Offset(
      arrowLen * math.cos(arrowAngle + arrowSpread),
      arrowLen * math.sin(arrowAngle + arrowSpread),
    );

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowP1.dx, arrowP1.dy)
      ..lineTo(arrowP2.dx, arrowP2.dy)
      ..close();

    canvas.drawPath(arrowPath, Paint()..color = powerColor);

    // 3. Power arc around striker
    final arcPaint = Paint()
      ..color = powerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = power * 2 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(
        center: start,
        radius: CarromConfig.strikerRadius + 5.0,
      ),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 8.0;
    const dashSpace = 5.0;
    final totalDist = (p2 - p1).distance;
    final direction = (p2 - p1) / totalDist;

    var currentDist = CarromConfig.strikerRadius + 4.0;
    while (currentDist < totalDist) {
      final start = p1 + direction * currentDist;
      final step = math.min(dashLength, totalDist - currentDist);
      final end = start + direction * step;
      canvas.drawLine(start, end, paint);
      currentDist += dashLength + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CarromBoardPainter oldDelegate) {
    return true; // Continuously repaints during drag and 60fps simulation
  }
}
