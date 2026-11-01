import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pen_fight_config.dart';
import 'pen_fight_controller.dart';
import 'pen_fight_models.dart';
import 'pen_fight_painter.dart';
import 'pen_fight_vec2.dart';

/// Interactive Tabletop Widget for Pen Fight.
/// Translates touch gestures to virtual coordinates and drives aiming and flicking.
class PenFightBoardWidget extends StatefulWidget {
  final PenFightController controller;
  final VoidCallback onShotFlicked;

  const PenFightBoardWidget({
    super.key,
    required this.controller,
    required this.onShotFlicked,
  });

  @override
  State<PenFightBoardWidget> createState() => _PenFightBoardWidgetState();
}

class _PenFightBoardWidgetState extends State<PenFightBoardWidget> {
  bool _isDragging = false;

  PenFightVec2 _screenToVirtual(Offset localPosition, Size widgetSize) {
    final scaleX = widgetSize.width / PenFightConfig.tableWidth;
    final scaleY = widgetSize.height / PenFightConfig.tableHeight;
    final scale = math.min(scaleX, scaleY);

    final offsetX = (widgetSize.width - PenFightConfig.tableWidth * scale) / 2.0;
    final offsetY = (widgetSize.height - PenFightConfig.tableHeight * scale) / 2.0;

    final vx = (localPosition.dx - offsetX) / scale;
    final vy = (localPosition.dy - offsetY) / scale;
    return PenFightVec2(vx, vy);
  }

  void _handlePanStart(DragStartDetails details, Size widgetSize) {
    final ctrl = widget.controller;
    if (!ctrl.canHumanAim(ctrl.currentTurn)) return;

    final virtualTouch = _screenToVirtual(details.localPosition, widgetSize);
    final shooter = ctrl.activeShooterPen;

    // Must start drag within reasonable touch radius of the active shooter pen
    const touchActivationRadius = PenFightConfig.penRadius * 3.5;
    if (virtualTouch.distanceTo(shooter.position) <= touchActivationRadius) {
      _isDragging = true;
      ctrl.startAim(ctrl.currentTurn, virtualTouch);
      setState(() {});
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, Size widgetSize) {
    if (!_isDragging) return;
    final ctrl = widget.controller;
    if (!ctrl.canHumanAim(ctrl.currentTurn)) {
      _isDragging = false;
      return;
    }

    final virtualTouch = _screenToVirtual(details.localPosition, widgetSize);
    ctrl.updateAim(virtualTouch);
    setState(() {});
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final ctrl = widget.controller;
    final flicked = ctrl.releaseFlick();
    if (flicked) {
      widget.onShotFlicked();
    }
    setState(() {});
  }

  void _handlePanCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    widget.controller.cancelAim();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce the table aspect ratio (400 : 600 = 2 : 3)
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        double boardW = maxW;
        double boardH = boardW / PenFightConfig.aspectRatio;

        if (boardH > maxH) {
          boardH = maxH;
          boardW = boardH * PenFightConfig.aspectRatio;
        }

        final boardSize = Size(boardW, boardH);

        return Center(
          child: SizedBox(
            key: const Key('pen_fight_tabletop_area'),
            width: boardW,
            height: boardH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _handlePanStart(d, boardSize),
              onPanUpdate: (d) => _handlePanUpdate(d, boardSize),
              onPanEnd: _handlePanEnd,
              onPanCancel: _handlePanCancel,
              child: CustomPaint(
                size: boardSize,
                painter: PenFightPainter(
                  pen1: ctrl.pen1,
                  pen2: ctrl.pen2,
                  currentAim: ctrl.currentAim,
                  activeTurn: ctrl.currentTurn,
                  isAimingPhase: ctrl.phase == PenFightPhase.aiming,
                  tableType: ctrl.currentTableType,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
