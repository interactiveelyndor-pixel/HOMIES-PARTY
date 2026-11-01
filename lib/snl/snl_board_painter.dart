import 'package:flutter/material.dart';
import 'snl_colors.dart';
import 'snl_config.dart';

/// Converts a cell number (1–100) to a row,col on the 10×10 board.
/// Row 0 = top (cells 91–100), row 9 = bottom (cells 1–10).
/// Even rows go left→right, odd rows go right→left (zigzag).
Offset snlCellToOffset(int cell) {
  // cell 1 = bottom-left, cell 100 = top-left
  final zeroIdx = cell - 1; // 0..99
  final boardRow = zeroIdx ~/ 10; // 0 = bottom row, 9 = top row
  final col = zeroIdx % 10;
  final displayRow = 9 - boardRow; // flip so row 9 is at top
  // Even boardRow → left to right; odd boardRow → right to left
  final displayCol = boardRow.isEven ? col : 9 - col;
  return Offset(displayCol.toDouble(), displayRow.toDouble());
}

/// CustomPainter that draws the 10×10 S&L board with snakes and ladders.
class SnlBoardPainter extends CustomPainter {
  const SnlBoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 10;
    final cellH = size.height / 10;

    _drawCells(canvas, size, cellW, cellH);
    _drawLadders(canvas, cellW, cellH);
    _drawSnakes(canvas, cellW, cellH);
  }

  void _drawCells(Canvas canvas, Size size, double cellW, double cellH) {
    final lightPaint = Paint()..color = SnlColors.boardLight;
    final darkPaint = Paint()..color = SnlColors.boardDark;
    final borderPaint = Paint()
      ..color = const Color(0xFFD1B97A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int row = 0; row < 10; row++) {
      for (int col = 0; col < 10; col++) {
        final rect =
            Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH);
        final isLight = (row + col).isEven;
        canvas.drawRect(rect, isLight ? lightPaint : darkPaint);
        canvas.drawRect(rect, borderPaint);

        // Cell number
        final boardRow = 9 - row; // 0=bottom
        final cellNum = boardRow.isEven
            ? boardRow * 10 + col + 1
            : boardRow * 10 + (9 - col) + 1;

        _drawCellNumber(canvas, cellNum, rect);
      }
    }
  }

  void _drawCellNumber(Canvas canvas, int num, Rect rect) {
    final isSnakeH = SnlConfig.isSnakeHead(num);
    final isLadderB = SnlConfig.isLadderBottom(num);
    final textColor = isSnakeH
        ? const Color(0xFFDC2626)
        : isLadderB
            ? const Color(0xFFB45309)
            : SnlColors.cellNumberDark;

    final tp = TextPainter(
      text: TextSpan(
        text: '$num',
        style: TextStyle(
          color: textColor,
          fontSize: rect.width * 0.22,
          fontWeight:
              (isSnakeH || isLadderB) ? FontWeight.bold : FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        rect.left + rect.width * 0.08,
        rect.top + rect.height * 0.06,
      ),
    );
  }

  void _drawLadders(Canvas canvas, double cellW, double cellH) {
    for (final entry in SnlConfig.ladders.entries) {
      final bottom = entry.key;
      final top = entry.value;
      _drawLadder(canvas, bottom, top, cellW, cellH);
    }
  }

  Offset _cellCenter(int cell, double cellW, double cellH) {
    final pos = snlCellToOffset(cell);
    return Offset(
      pos.dx * cellW + cellW * 0.5,
      pos.dy * cellH + cellH * 0.5,
    );
  }

  void _drawLadder(
      Canvas canvas, int bottom, int top, double cellW, double cellH) {
    final bCenter = _cellCenter(bottom, cellW, cellH);
    final tCenter = _cellCenter(top, cellW, cellH);

    final dx = tCenter.dx - bCenter.dx;
    final dy = tCenter.dy - bCenter.dy;
    final len = Offset(dx, dy).distance;
    if (len < 1) return;

    // Unit perpendicular
    final perpX = -dy / len;
    final perpY = dx / len;
    final halfWidth = cellW * 0.12;

    final sidePaint = Paint()
      ..color = SnlColors.ladderSide
      ..strokeWidth = cellW * 0.065
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Two side rails
    canvas.drawLine(
      Offset(bCenter.dx + perpX * halfWidth, bCenter.dy + perpY * halfWidth),
      Offset(tCenter.dx + perpX * halfWidth, tCenter.dy + perpY * halfWidth),
      sidePaint,
    );
    canvas.drawLine(
      Offset(bCenter.dx - perpX * halfWidth, bCenter.dy - perpY * halfWidth),
      Offset(tCenter.dx - perpX * halfWidth, tCenter.dy - perpY * halfWidth),
      sidePaint,
    );

    // Rungs
    final rungPaint = Paint()
      ..color = SnlColors.ladderRung
      ..strokeWidth = cellW * 0.055
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const rungCount = 5;
    for (int i = 1; i <= rungCount; i++) {
      final t = i / (rungCount + 1);
      final rx = bCenter.dx + dx * t;
      final ry = bCenter.dy + dy * t;
      canvas.drawLine(
        Offset(rx + perpX * halfWidth, ry + perpY * halfWidth),
        Offset(rx - perpX * halfWidth, ry - perpY * halfWidth),
        rungPaint,
      );
    }

    // Glow dot at top
    canvas.drawCircle(
      tCenter,
      cellW * 0.13,
      Paint()..color = SnlColors.ladderAccent.withValues(alpha: 0.7),
    );
  }

  void _drawSnakes(Canvas canvas, double cellW, double cellH) {
    for (final entry in SnlConfig.snakes.entries) {
      final head = entry.key;
      final tail = entry.value;
      _drawSnake(canvas, head, tail, cellW, cellH);
    }
  }

  void _drawSnake(
      Canvas canvas, int head, int tail, double cellW, double cellH) {
    final hCenter = _cellCenter(head, cellW, cellH);
    final tCenter = _cellCenter(tail, cellW, cellH);

    final dx = tCenter.dx - hCenter.dx;
    final dy = tCenter.dy - hCenter.dy;
    final len = Offset(dx, dy).distance;
    if (len < 1) return;

    // Draw a simple curved snake body using a bezier curve
    final mid1 = Offset(
      hCenter.dx + dx * 0.3 + dy * 0.25,
      hCenter.dy + dy * 0.3 - dx * 0.25,
    );
    final mid2 = Offset(
      hCenter.dx + dx * 0.7 - dy * 0.25,
      hCenter.dy + dy * 0.7 + dx * 0.25,
    );

    final path = Path()
      ..moveTo(hCenter.dx, hCenter.dy)
      ..cubicTo(mid1.dx, mid1.dy, mid2.dx, mid2.dy, tCenter.dx, tCenter.dy);

    // Shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = cellW * 0.14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Body
    canvas.drawPath(
      path,
      Paint()
        ..color = SnlColors.snakeBody
        ..strokeWidth = cellW * 0.11
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Scales highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = SnlColors.snakeAccent.withValues(alpha: 0.4)
        ..strokeWidth = cellW * 0.04
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Head circle
    canvas.drawCircle(
      hCenter,
      cellW * 0.18,
      Paint()..color = SnlColors.snakeHead,
    );
    // Head eye
    canvas.drawCircle(
      Offset(hCenter.dx + cellW * 0.06, hCenter.dy - cellW * 0.06),
      cellW * 0.05,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(hCenter.dx + cellW * 0.06, hCenter.dy - cellW * 0.06),
      cellW * 0.025,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant SnlBoardPainter oldDelegate) => false;
}
