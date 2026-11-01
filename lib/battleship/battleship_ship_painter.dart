import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'battleship_colors.dart';
import 'battleship_models.dart';

/// CustomPainter rendering recognizable silhouettes for each ship type:
/// - Battleship (4 cells): Armored hull, fore & aft gun turrets, central bridge
/// - Cruiser (3 cells): Streamlined cruiser hull, forward turret, command tower
/// - Submarine (3 cells): Rounded hull, conning tower sail, and small periscope
/// - Destroyer (2 cells): Compact nimble hull, forward gun mount, compact bridge
class BattleshipShipPainter extends CustomPainter {
  final ShipType type;
  final ShipOrientation orientation;
  final bool isSunk;
  final Color? customColor;

  const BattleshipShipPainter({
    required this.type,
    required this.orientation,
    this.isSunk = false,
    this.customColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    final isHorizontal = orientation == ShipOrientation.horizontal;
    double lengthPx;
    double widthPx;

    if (isHorizontal) {
      lengthPx = size.width;
      widthPx = size.height;
    } else {
      // Rotate 90 degrees so we draw horizontally along lengthPx
      canvas.translate(size.width, 0);
      canvas.rotate(math.pi / 2);
      lengthPx = size.height;
      widthPx = size.width;
    }

    final hullColor = customColor ??
        (isSunk ? const Color(0xFF7F1D1D) : const Color(0xFF334155));
    final accentColor = isSunk
        ? const Color(0xFFEF4444)
        : BattleshipColors.accentCyan.withValues(alpha: 0.85);
    final detailColor = isSunk
        ? const Color(0xFF991B1B)
        : const Color(0xFF475569);

    final hullPaint = Paint()
      ..color = hullColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final detailPaint = Paint()
      ..color = detailColor
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final margin = widthPx * 0.14;
    final top = margin;
    final bottom = widthPx - margin;
    final centerY = widthPx / 2;
    final hullHeight = bottom - top;

    switch (type) {
      case ShipType.battleship:
        _drawBattleship(
          canvas,
          lengthPx,
          top,
          bottom,
          centerY,
          hullHeight,
          hullPaint,
          borderPaint,
          detailPaint,
          accentPaint,
        );
        break;
      case ShipType.cruiser:
        _drawCruiser(
          canvas,
          lengthPx,
          top,
          bottom,
          centerY,
          hullHeight,
          hullPaint,
          borderPaint,
          detailPaint,
          accentPaint,
        );
        break;
      case ShipType.submarine:
        _drawSubmarine(
          canvas,
          lengthPx,
          top,
          bottom,
          centerY,
          hullHeight,
          hullPaint,
          borderPaint,
          detailPaint,
          accentPaint,
        );
        break;
      case ShipType.destroyer:
        _drawDestroyer(
          canvas,
          lengthPx,
          top,
          bottom,
          centerY,
          hullHeight,
          hullPaint,
          borderPaint,
          detailPaint,
          accentPaint,
        );
        break;
    }

    canvas.restore();
  }

  void _drawBattleship(
    Canvas canvas,
    double len,
    double top,
    double bottom,
    double centerY,
    double h,
    Paint hull,
    Paint border,
    Paint detail,
    Paint accent,
  ) {
    // Heavy warship hull: sharp angled bow at right, flat stern at left
    final path = Path()
      ..moveTo(4, top + h * 0.2)
      ..lineTo(len - h * 0.9, top)
      ..lineTo(len - 2, centerY)
      ..lineTo(len - h * 0.9, bottom)
      ..lineTo(4, bottom - h * 0.2)
      ..close();

    canvas.drawPath(path, hull);
    canvas.drawPath(path, border);

    // Deck plating
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(len * 0.15, top + h * 0.22, len * 0.82, bottom - h * 0.22),
        const Radius.circular(2),
      ),
      detail,
    );

    // Central bridge / superstructure
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(len * 0.5, centerY),
          width: len * 0.22,
          height: h * 0.45,
        ),
        const Radius.circular(2),
      ),
      accent,
    );

    // Gun turrets (bow turret & aft turret)
    canvas.drawCircle(Offset(len * 0.72, centerY), h * 0.16, accent);
    canvas.drawLine(
      Offset(len * 0.72, centerY),
      Offset(len * 0.85, centerY),
      border..strokeWidth = 1.6,
    );

    canvas.drawCircle(Offset(len * 0.28, centerY), h * 0.16, accent);
    canvas.drawLine(
      Offset(len * 0.28, centerY),
      Offset(len * 0.15, centerY),
      border..strokeWidth = 1.6,
    );
  }

  void _drawCruiser(
    Canvas canvas,
    double len,
    double top,
    double bottom,
    double centerY,
    double h,
    Paint hull,
    Paint border,
    Paint detail,
    Paint accent,
  ) {
    // Sleek cruiser hull
    final path = Path()
      ..moveTo(3, top + h * 0.3)
      ..lineTo(len - h * 0.8, top + h * 0.05)
      ..lineTo(len - 2, centerY)
      ..lineTo(len - h * 0.8, bottom - h * 0.05)
      ..lineTo(3, bottom - h * 0.3)
      ..close();

    canvas.drawPath(path, hull);
    canvas.drawPath(path, border);

    // Center deck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(len * 0.5, centerY),
          width: len * 0.35,
          height: h * 0.42,
        ),
        const Radius.circular(2),
      ),
      detail,
    );

    // Command tower
    canvas.drawCircle(Offset(len * 0.54, centerY), h * 0.16, accent);

    // Forward turret
    canvas.drawCircle(Offset(len * 0.76, centerY), h * 0.14, accent);
    canvas.drawLine(
      Offset(len * 0.76, centerY),
      Offset(len * 0.88, centerY),
      border..strokeWidth = 1.5,
    );
  }

  void _drawSubmarine(
    Canvas canvas,
    double len,
    double top,
    double bottom,
    double centerY,
    double h,
    Paint hull,
    Paint border,
    Paint detail,
    Paint accent,
  ) {
    // Cylindrical rounded hull at bow & stern
    final hullRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(4, top + h * 0.15, len - 4, bottom - h * 0.15),
      Radius.circular(h * 0.4),
    );
    canvas.drawRRect(hullRect, hull);
    canvas.drawRRect(hullRect, border);

    // Conning tower (sail)
    final sailRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(len * 0.52, centerY),
        width: len * 0.22,
        height: h * 0.55,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(sailRect, detail);
    canvas.drawRRect(sailRect, border);

    // Small prominent Periscope sticking out!
    final periscopeBaseX = len * 0.54;
    final periscopeTopY = top - 1.5;
    // Vertical mast
    canvas.drawLine(
      Offset(periscopeBaseX, centerY - h * 0.2),
      Offset(periscopeBaseX, periscopeTopY),
      border..strokeWidth = 1.8,
    );
    // Horizontal eye optic
    canvas.drawLine(
      Offset(periscopeBaseX - 1.5, periscopeTopY),
      Offset(periscopeBaseX + 3.0, periscopeTopY),
      border..strokeWidth = 1.8,
    );
    canvas.drawCircle(Offset(periscopeBaseX + 2.5, periscopeTopY), 1.2, accent);
  }

  void _drawDestroyer(
    Canvas canvas,
    double len,
    double top,
    double bottom,
    double centerY,
    double h,
    Paint hull,
    Paint border,
    Paint detail,
    Paint accent,
  ) {
    // Compact agile patrol hull
    final path = Path()
      ..moveTo(3, top + h * 0.25)
      ..lineTo(len - h * 0.7, top + h * 0.1)
      ..lineTo(len - 2, centerY)
      ..lineTo(len - h * 0.7, bottom - h * 0.1)
      ..lineTo(3, bottom - h * 0.25)
      ..close();

    canvas.drawPath(path, hull);
    canvas.drawPath(path, border);

    // Compact bridge & single forward turret
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(len * 0.44, centerY),
          width: len * 0.28,
          height: h * 0.42,
        ),
        const Radius.circular(2),
      ),
      detail,
    );

    canvas.drawCircle(Offset(len * 0.72, centerY), h * 0.14, accent);
    canvas.drawLine(
      Offset(len * 0.72, centerY),
      Offset(len * 0.84, centerY),
      border..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant BattleshipShipPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.orientation != orientation ||
      oldDelegate.isSunk != isSunk ||
      oldDelegate.customColor != customColor;
}

/// CustomPainter rendering a drawn explosion / burst for HIT cells.
class ExplosionPainter extends CustomPainter {
  const ExplosionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;

    final outerBurstPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    final midFlamePaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.fill;

    final coreFirePaint = Paint()
      ..color = const Color(0xFFFDE047)
      ..style = PaintingStyle.fill;

    // Draw multi-pointed star burst
    const numPoints = 8;
    final burstPath = Path();
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi) / numPoints;
      final r = (i % 2 == 0) ? radius : radius * 0.45;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        burstPath.moveTo(x, y);
      } else {
        burstPath.lineTo(x, y);
      }
    }
    burstPath.close();
    canvas.drawPath(burstPath, outerBurstPaint);

    // Mid fire burst
    canvas.drawCircle(center, radius * 0.55, midFlamePaint);

    // Bright core ember
    canvas.drawCircle(center, radius * 0.28, coreFirePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter rendering a soft water splash / ripple for MISS cells.
class SplashRipplePainter extends CustomPainter {
  const SplashRipplePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.38;

    final outerRing = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final innerRing = Paint()
      ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final droplet = Paint()
      ..color = const Color(0xFFBAE6FD)
      ..style = PaintingStyle.fill;

    // Outer ripple ring
    canvas.drawCircle(center, maxRadius, outerRing);
    // Inner ripple ring
    canvas.drawCircle(center, maxRadius * 0.6, innerRing);
    // Central splash droplet
    canvas.drawCircle(center, maxRadius * 0.22, droplet);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
