import 'package:flutter/material.dart';
import 'carrom_board_painter.dart';
import 'carrom_config.dart';
import 'carrom_controller.dart';
import 'carrom_models.dart';
import 'carrom_vec2.dart';

/// Interactive widget hosting the Carrom CustomPainter and converting touch
/// gestures to virtual board coordinates for aiming, positioning, and shooting.
class CarromBoardWidget extends StatelessWidget {
  final CarromController controller;
  final double boardSize;

  /// When true, all gesture input is suppressed regardless of game phase.
  /// Used by [CarromGameScreen] to block human input during the CPU's turn.
  final bool blockInput;

  const CarromBoardWidget({
    super.key,
    required this.controller,
    required this.boardSize,
    this.blockInput = false,
  });

  CarromVec2 _toVirtualCoordinates(Offset localOffset) {
    final scale = CarromConfig.boardSize / boardSize;
    return CarromVec2(localOffset.dx * scale, localOffset.dy * scale);
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final isInputBlocked = blockInput ||
        state.phase == CarromTurnPhase.simulating ||
        state.phase == CarromTurnPhase.gameOver;

    return Container(
      width: boardSize,
      height: boardSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: isInputBlocked
              ? null
              : (details) {
                  final virtualPoint =
                      _toVirtualCoordinates(details.localPosition);
                  final striker = state.striker;

                  // Check if touch is near striker or baseline
                  final distToStriker =
                      virtualPoint.distanceTo(striker.position);
                  final distToBaseline =
                      (virtualPoint.y - state.currentBaselineY).abs();

                  if (distToStriker <= CarromConfig.strikerRadius * 2.8) {
                    controller.startAiming(virtualPoint);
                  } else if (distToBaseline <= 40.0) {
                    // Tap on baseline slides striker to that X position
                    controller.setStrikerPosition(virtualPoint.x);
                  }
                },
          onPanUpdate: isInputBlocked
              ? null
              : (details) {
                  final virtualPoint =
                      _toVirtualCoordinates(details.localPosition);
                  if (state.phase == CarromTurnPhase.aiming) {
                    controller.updateAim(virtualPoint);
                  } else if (state.phase ==
                      CarromTurnPhase.positioningStriker) {
                    // Check if dragging along baseline
                    final distToBaseline =
                        (virtualPoint.y - state.currentBaselineY).abs();
                    if (distToBaseline <= 50.0) {
                      controller.setStrikerPosition(virtualPoint.x);
                    }
                  }
                },
          onPanEnd: isInputBlocked
              ? null
              : (details) {
                  if (state.phase == CarromTurnPhase.aiming) {
                    controller.releaseShot();
                  }
                },
          onPanCancel: isInputBlocked
              ? null
              : () {
                  if (state.phase == CarromTurnPhase.aiming) {
                    controller.cancelAim();
                  }
                },
          child: CustomPaint(
            size: Size(boardSize, boardSize),
            painter: CarromBoardPainter(state: state),
          ),
        ),
      ),
    );
  }
}
