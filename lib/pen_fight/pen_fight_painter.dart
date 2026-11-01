import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pen_fight_config.dart';
import 'pen_fight_models.dart';
import 'pen_fight_theme.dart';

/// CustomPainter that renders the Pen Fight tabletop, rigid-body pens,
/// trajectory aim line, and power indicator.
class PenFightPainter extends CustomPainter {
  final Pen pen1;
  final Pen pen2;
  final PenFightAim? currentAim;
  final PenFightPlayerId activeTurn;
  final bool isAimingPhase;
  final PenFightTableType tableType;

  PenFightPainter({
    required this.pen1,
    required this.pen2,
    required this.currentAim,
    required this.activeTurn,
    required this.isAimingPhase,
    this.tableType = PenFightTableType.classic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Virtual coordinate system: 420x420 square table.
    final scaleX = size.width / PenFightConfig.tableWidth;
    final scaleY = size.height / PenFightConfig.tableHeight;
    final scale = math.min(scaleX, scaleY);

    final offsetX = (size.width - PenFightConfig.tableWidth * scale) / 2.0;
    final offsetY = (size.height - PenFightConfig.tableHeight * scale) / 2.0;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // 1. Draw Tabletop Surface, Wooden Bevel, and Table Features
    _drawTabletop(canvas);

    // 2. Draw Aim Line & Power Meter
    if (currentAim != null && isAimingPhase) {
      final shooter = activeTurn == PenFightPlayerId.player1 ? pen1 : pen2;
      _drawAim(canvas, currentAim!, shooter);
    }

    // 3. Draw Pens (with type-specific graphics)
    _drawPen(canvas, pen1, isP1: true);
    _drawPen(canvas, pen2, isP1: false);

    canvas.restore();
  }

  void _drawTabletop(Canvas canvas) {
    final tableRect = Rect.fromLTWH(
      0.0,
      0.0,
      PenFightConfig.tableWidth,
      PenFightConfig.tableHeight,
    );

    // 1. Soft Shadow under the table
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect.inflate(2.0), const Radius.circular(16)),
      shadowPaint,
    );

    // 2. Beveled Wooden Frame (Warm Walnut / Mahogany)
    final outerFramePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF5D3823), // Rich walnut highlight
          Color(0xFF381F12), // Deep wood
          Color(0xFF24130A), // Shadowed wood
        ],
      ).createShader(tableRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect, const Radius.circular(16)),
      outerFramePaint,
    );

    // Frame bevel highlight & shadow
    final frameHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tableRect.deflate(1.0), const Radius.circular(15)),
      frameHighlightPaint,
    );

    // 3. Inner Tabletop Surface (Varnished wood / tournament felt)
    const frameBorderWidth = 10.0;
    final innerSurfaceRect = tableRect.deflate(frameBorderWidth);
    final surfacePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2A1C15), // Varnished dark oak top
          Color(0xFF1F140E), // Warm dark center
          Color(0xFF160E0A), // Rich dark bottom
        ],
      ).createShader(innerSurfaceRect);
    final roundedSurface = RRect.fromRectAndRadius(
      innerSurfaceRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(roundedSurface, surfacePaint);

    // Subtle radial sheen in tabletop center
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(innerSurfaceRect);
    canvas.drawRRect(roundedSurface, sheenPaint);

    // Subtle fine wood-grain lines
    final grainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 7; i++) {
      final y = innerSurfaceRect.top + (innerSurfaceRect.height / 8.0) * i;
      canvas.drawLine(
        Offset(innerSurfaceRect.left + 10, y),
        Offset(innerSurfaceRect.right - 10, y),
        grainPaint,
      );
    }

    // Subtle table center dividing line & duel ring
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(innerSurfaceRect.left + 24.0, PenFightConfig.tableHeight / 2),
      Offset(innerSurfaceRect.right - 24.0, PenFightConfig.tableHeight / 2),
      centerLinePaint,
    );
    final centerCirclePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      const Offset(PenFightConfig.tableWidth / 2, PenFightConfig.tableHeight / 2),
      40.0,
      centerCirclePaint,
    );

    // 4. Table Type Specific Elements:
    switch (tableType) {
      case PenFightTableType.classic:
        // Clear open edge danger perimeter warning line
        final dangerPaint = Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.16)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(roundedSurface.deflate(6.0), dangerPaint);
        break;

      case PenFightTableType.hole:
        // Open edge danger perimeter
        final dangerPaint = Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.14)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(roundedSurface.deflate(6.0), dangerPaint);

        // Draw middle hole hazard with dark rim and 3D depth
        _drawTableHole(canvas);
        break;
    }
  }

  void _drawTableHole(Canvas canvas) {
    final center = Offset(PenFightConfig.holeCenter.x, PenFightConfig.holeCenter.y);
    const radius = PenFightConfig.holeRadius;

    // 1. Hole Outer Drop Shadow on tabletop
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius + 2.0, shadowPaint);

    // 2. Brass / Metallic Rim Bevel
    final rimPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFD97706), // Warm brass highlight
          Color(0xFF78350F), // Dark brass bevel
          Color(0xFF1E130B), // Inner dark lip
        ],
        stops: [0.75, 0.90, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius + 4.5));
    canvas.drawCircle(center, radius + 4.5, rimPaint);

    // 3. Deep Void Black Interior (with radial depth gradient)
    final holePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3), // Top-left inner shadow light source
        radius: 0.9,
        colors: const [
          Color(0xFF0F172A), // Soft dark rim glow
          Color(0xFF050914), // Deep void
          Color(0xFF020408), // Pitch black bottom
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, holePaint);

    // 4. Inner Top Shadow / Lip Crease for true 3D depth
    final innerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.85)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.5),
      math.pi,
      math.pi,
      false,
      innerShadowPaint,
    );

    // 5. Subtle Danger Hazard Ring around hole
    final hazardRingPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.35)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius + 7.0, hazardRingPaint);
  }

  void _drawPen(Canvas canvas, Pen pen, {required bool isP1}) {
    canvas.save();

    final isOff = pen.isOffTable;
    final drawPos = pen.position;
    var scale = 1.0;
    var opacity = 1.0;

    if (isOff) {
      final t = pen.fallProgress.clamp(0.0, 1.0);
      scale = 1.0 - 0.5 * t;
      opacity = (1.0 - t).clamp(0.0, 1.0);
    }

    canvas.translate(drawPos.x, drawPos.y);
    canvas.scale(scale);
    // Align visual pen drawing (+Y nib, -Y cap) with physical capsule (forward along X)
    canvas.rotate(pen.angle - math.pi / 2);

    final baseColor = isP1 ? PenFightTheme.p1PenBody : PenFightTheme.p2PenBody;
    final highlightColor =
        isP1 ? PenFightTheme.p1PenHighlight : PenFightTheme.p2PenHighlight;
    final accentColor =
        isP1 ? PenFightTheme.p1PenAccent : PenFightTheme.p2PenAccent;
    final isActive = isAimingPhase &&
        (isP1
            ? activeTurn == PenFightPlayerId.player1
            : activeTurn == PenFightPlayerId.player2);

    final halfL = pen.length / 2.0;
    final halfW = pen.width / 2.0;
    final radius = pen.radius;

    // 1. Soft Pen Shadow
    if (!isOff) {
      final shadowBlur = pen.type == PenType.heavy ? 7.0 : 4.5;
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(3.0, 4.0),
          width: pen.width * 2.2,
          height: pen.length * 0.95,
        ),
        shadowPaint,
      );
    }

    // 2. Active Glow Ring
    if (isActive && !isOff) {
      final glowPaint = Paint()
        ..color = highlightColor.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      canvas.drawCircle(Offset.zero, radius + 7.0, glowPaint);
    }

    // 3. Collision Capsule Indicator (Subtle outline showing exact physical bounds)
    final capsulePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: pen.width,
            height: pen.length,
          ),
          Radius.circular(radius),
        ),
      );
    final boundsBorder = Paint()
      ..color = highlightColor.withValues(alpha: 0.25 * opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(capsulePath, boundsBorder);

    // 4. Stylized Pen Body Graphics (Heavy, Slim, or Balanced)
    switch (pen.type) {
      case PenType.heavy:
        _drawHeavyPenGraphic(
          canvas,
          halfL,
          halfW,
          baseColor,
          highlightColor,
          accentColor,
          opacity,
        );
        break;
      case PenType.slim:
        _drawSlimPenGraphic(
          canvas,
          halfL,
          halfW,
          baseColor,
          highlightColor,
          accentColor,
          opacity,
        );
        break;
      case PenType.balanced:
        _drawBalancedPenGraphic(
          canvas,
          halfL,
          halfW,
          baseColor,
          highlightColor,
          accentColor,
          opacity,
        );
        break;
    }

    canvas.restore();
  }

  void _drawBalancedPenGraphic(
    Canvas canvas,
    double halfL,
    double halfW,
    Color baseColor,
    Color highlightColor,
    Color accentColor,
    double opacity,
  ) {
    // Barrel
    final barrelRect = Rect.fromLTRB(-halfW, -halfL + 14, halfW, halfL - 10);
    final barrelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          baseColor.withValues(alpha: opacity),
          highlightColor.withValues(alpha: opacity),
          baseColor.withValues(alpha: opacity),
        ],
      ).createShader(barrelRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrelRect, const Radius.circular(3)),
      barrelPaint,
    );

    // Grip Lines (4 lines)
    final gripPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3 * opacity)
      ..strokeWidth = 1.5;
    for (var i = 0; i < 4; i++) {
      final y = halfL - 24.0 + i * 3.5;
      canvas.drawLine(Offset(-halfW + 1, y), Offset(halfW - 1, y), gripPaint);
    }

    // Cone & Nib
    final nibPath = Path()
      ..moveTo(-halfW * 0.7, halfL - 10)
      ..lineTo(0.0, halfL + 6)
      ..lineTo(halfW * 0.7, halfL - 10)
      ..close();
    final nibPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(nibPath, nibPaint);

    final tipPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: opacity);
    canvas.drawCircle(Offset(0.0, halfL + 6), 1.6, tipPaint);

    // End Cap
    final capRect = Rect.fromLTRB(-halfW * 0.85, -halfL, halfW * 0.85, -halfL + 14);
    final capPaint = Paint()
      ..color = accentColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(4)),
      capPaint,
    );

    // Pocket Clip
    final clipPath = Path()
      ..moveTo(halfW * 0.35, -halfL + 4)
      ..lineTo(halfW * 0.35, -halfL + 30)
      ..lineTo(halfW * 0.8, -halfL + 28)
      ..lineTo(halfW * 0.8, -halfL + 4)
      ..close();
    final clipPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(clipPath, clipPaint);
  }

  void _drawHeavyPenGraphic(
    Canvas canvas,
    double halfL,
    double halfW,
    Color baseColor,
    Color highlightColor,
    Color accentColor,
    double opacity,
  ) {
    // Broad, rugged barrel
    final barrelRect = Rect.fromLTRB(-halfW, -halfL + 16, halfW, halfL - 12);
    final barrelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color.lerp(baseColor, Colors.black, 0.2)!.withValues(alpha: opacity),
          highlightColor.withValues(alpha: opacity),
          Color.lerp(baseColor, Colors.black, 0.2)!.withValues(alpha: opacity),
        ],
      ).createShader(barrelRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrelRect, const Radius.circular(4)),
      barrelPaint,
    );

    // Double metallic accent rings
    final goldBandPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: opacity)
      ..strokeWidth = 2.2;
    canvas.drawLine(Offset(-halfW, halfL - 16), Offset(halfW, halfL - 16), goldBandPaint);
    canvas.drawLine(Offset(-halfW, -halfL + 20), Offset(halfW, -halfL + 20), goldBandPaint);

    // Heavy knurled grip
    final knurlPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4 * opacity)
      ..strokeWidth = 2.0;
    for (var i = 0; i < 5; i++) {
      final y = halfL - 26.0 + i * 3.0;
      canvas.drawLine(Offset(-halfW + 1, y), Offset(halfW - 1, y), knurlPaint);
    }

    // Heavy chisel nib
    final nibPath = Path()
      ..moveTo(-halfW * 0.8, halfL - 12)
      ..lineTo(-halfW * 0.3, halfL + 7)
      ..lineTo(halfW * 0.3, halfL + 7)
      ..lineTo(halfW * 0.8, halfL - 12)
      ..close();
    final nibPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(nibPath, nibPaint);

    // Heavy reinforced cap
    final capRect = Rect.fromLTRB(-halfW * 0.95, -halfL, halfW * 0.95, -halfL + 16);
    final capPaint = Paint()
      ..color = accentColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(5)),
      capPaint,
    );

    // Wide reinforced clip
    final clipPath = Path()
      ..moveTo(halfW * 0.3, -halfL + 3)
      ..lineTo(halfW * 0.3, -halfL + 34)
      ..lineTo(halfW * 0.9, -halfL + 32)
      ..lineTo(halfW * 0.9, -halfL + 3)
      ..close();
    final clipPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(clipPath, clipPaint);
  }

  void _drawSlimPenGraphic(
    Canvas canvas,
    double halfL,
    double halfW,
    Color baseColor,
    Color highlightColor,
    Color accentColor,
    double opacity,
  ) {
    // Sleek needle barrel
    final barrelRect = Rect.fromLTRB(-halfW, -halfL + 12, halfW, halfL - 8);
    final barrelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          baseColor.withValues(alpha: opacity),
          Color.lerp(highlightColor, Colors.white, 0.3)!.withValues(alpha: opacity),
          baseColor.withValues(alpha: opacity),
        ],
      ).createShader(barrelRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrelRect, const Radius.circular(2)),
      barrelPaint,
    );

    // Slim fine grip ring
    final slimGripPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45 * opacity)
      ..strokeWidth = 1.0;
    for (var i = 0; i < 3; i++) {
      final y = halfL - 18.0 + i * 3.0;
      canvas.drawLine(Offset(-halfW + 0.5, y), Offset(halfW - 0.5, y), slimGripPaint);
    }

    // Needle-point fine nib
    final nibPath = Path()
      ..moveTo(-halfW * 0.6, halfL - 8)
      ..lineTo(0.0, halfL + 7)
      ..lineTo(halfW * 0.6, halfL - 8)
      ..close();
    final nibPaint = Paint()
      ..color = const Color(0xFFF1F5F9).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(nibPath, nibPaint);

    final tipPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: opacity);
    canvas.drawCircle(Offset(0.0, halfL + 7), 1.2, tipPaint);

    // Slim tapered cap
    final capRect = Rect.fromLTRB(-halfW * 0.8, -halfL, halfW * 0.8, -halfL + 12);
    final capPaint = Paint()
      ..color = accentColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(3)),
      capPaint,
    );

    // Slender needle clip
    final clipPath = Path()
      ..moveTo(halfW * 0.4, -halfL + 3)
      ..lineTo(halfW * 0.4, -halfL + 24)
      ..lineTo(halfW * 0.75, -halfL + 23)
      ..lineTo(halfW * 0.75, -halfL + 3)
      ..close();
    final clipPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(clipPath, clipPaint);
  }

  void _drawAim(Canvas canvas, PenFightAim aim, Pen shooter) {
    final origin = Offset(aim.origin.x, aim.origin.y);
    final dragCurrent = Offset(aim.dragCurrent.x, aim.dragCurrent.y);
    final aimDir = aim.aimDirection;
    final fraction = aim.powerFraction;
    final aimColor = PenFightTheme.getPowerColor(fraction);

    // 1. Drag feedback line (slingshot pull backward, shortened to match 38.5px max)
    final pullPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(origin, dragCurrent, pullPaint);

    // Drag handle circle with glow
    final handleGlowPaint = Paint()
      ..color = aimColor.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(dragCurrent, 8.0, handleGlowPaint);

    final handlePaint = Paint()
      ..color = aimColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dragCurrent, 6.5, handlePaint);

    final handleInnerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(dragCurrent, 2.5, handleInnerPaint);

    // 2. Shortened Forward Trajectory Aim Line (~50% shorter to match reduced drag)
    final aimLength = 28.0 + fraction * 72.0;
    final aimEnd = Offset(
      origin.dx + aimDir.x * aimLength,
      origin.dy + aimDir.y * aimLength,
    );

    // Glowing aim line
    final glowAimPaint = Paint()
      ..color = aimColor.withValues(alpha: 0.40)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, aimEnd, glowAimPaint);

    final linePaint = Paint()
      ..color = aimColor
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(origin, aimEnd, linePaint);

    // Dotted trajectory dots
    const dotSpacing = 12.0;
    final dotCount = (aimLength / dotSpacing).floor();
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 1; i <= dotCount; i++) {
      final t = (i * dotSpacing) / aimLength;
      final dotOffset = Offset.lerp(origin, aimEnd, t)!;
      canvas.drawCircle(dotOffset, 1.8, dotPaint);
    }

    // Arrowhead at the tip of the trajectory line
    final arrowAngle = math.atan2(aimDir.y, aimDir.x);
    const arrowHeadLen = 10.0;
    const arrowHeadAngle = 0.45;

    final p1 = Offset(
      aimEnd.dx - arrowHeadLen * math.cos(arrowAngle - arrowHeadAngle),
      aimEnd.dy - arrowHeadLen * math.sin(arrowAngle - arrowHeadAngle),
    );
    final p2 = Offset(
      aimEnd.dx - arrowHeadLen * math.cos(arrowAngle + arrowHeadAngle),
      aimEnd.dy - arrowHeadLen * math.sin(arrowAngle + arrowHeadAngle),
    );

    final arrowPath = Path()
      ..moveTo(aimEnd.dx, aimEnd.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final arrowPaint = Paint()
      ..color = aimColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);

    // 3. Polished Glowing Power Meter Arc around Shooter Pen
    final arcRadius = shooter.radius + 13.0;
    final arcRect = Rect.fromCircle(
      center: origin,
      radius: arcRadius,
    );

    // Background track
    final arcBgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, arcBgPaint);

    // Glowing filled power arc
    if (fraction > 0.01) {
      final arcGlowPaint = Paint()
        ..color = aimColor.withValues(alpha: 0.5)
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        arcGlowPaint,
      );

      final arcFillPaint = Paint()
        ..color = aimColor
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        arcFillPaint,
      );

      // Glowing power tip pip
      final tipAngle = -math.pi / 2 + math.pi * 2 * fraction;
      final tipPos = Offset(
        origin.dx + arcRadius * math.cos(tipAngle),
        origin.dy + arcRadius * math.sin(tipAngle),
      );
      final pipPaint = Paint()..color = Colors.white;
      canvas.drawCircle(tipPos, 2.5, pipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PenFightPainter oldDelegate) => true;
}
