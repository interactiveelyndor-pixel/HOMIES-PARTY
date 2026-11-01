import 'package:flutter/material.dart';
import '../models/player_color.dart';
import '../theme/ludo_theme.dart';

class CenterHomeWidget extends StatelessWidget {
  final double size;

  const CenterHomeWidget({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CenterHomePainter(),
        child: Center(
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFD97706),
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterHomePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final paintRed = Paint()
      ..color = LudoTheme.getPrimary(PlayerColor.red)
      ..style = PaintingStyle.fill;

    final paintGreen = Paint()
      ..color = LudoTheme.getPrimary(PlayerColor.green)
      ..style = PaintingStyle.fill;

    final paintYellow = Paint()
      ..color = LudoTheme.getPrimary(PlayerColor.yellow)
      ..style = PaintingStyle.fill;

    final paintBlue = Paint()
      ..color = LudoTheme.getPrimary(PlayerColor.blue)
      ..style = PaintingStyle.fill;

    // Top Triangle (Green)
    final pathGreen = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathGreen, paintGreen);

    // Right Triangle (Yellow)
    final pathYellow = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathYellow, paintYellow);

    // Bottom Triangle (Blue)
    final pathBlue = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathBlue, paintBlue);

    // Left Triangle (Red)
    final pathRed = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 0)
      ..lineTo(center.dx, center.dy)
      ..close();
    canvas.drawPath(pathRed, paintRed);

    // Triangle dividing borders
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width, size.height), borderPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
