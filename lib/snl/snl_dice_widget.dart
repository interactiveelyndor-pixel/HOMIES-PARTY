import 'dart:math';
import 'package:flutter/material.dart';
import 'snl_colors.dart';

/// Standalone dice widget for Snakes & Ladders.
/// Does NOT depend on LudoController, LudoTheme, or PlayerColor.
class SnlDiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool canRoll;
  final Color accentColor;
  final VoidCallback? onRoll;
  final double size;

  const SnlDiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.canRoll,
    this.accentColor = SnlColors.accent,
    this.onRoll,
    this.size = 52.0,
  });

  @override
  State<SnlDiceWidget> createState() => _SnlDiceWidgetState();
}

class _SnlDiceWidgetState extends State<SnlDiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _displayValue = 1;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value ?? 1;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _controller.addListener(() {
      if (widget.isRolling) {
        setState(() => _displayValue = _rng.nextInt(6) + 1);
      }
    });
    if (widget.isRolling) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SnlDiceWidget old) {
    super.didUpdateWidget(old);
    if (widget.isRolling != old.isRolling) {
      if (widget.isRolling) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
        _displayValue = widget.value ?? 1;
      }
    } else if (!widget.isRolling && widget.value != null) {
      _displayValue = widget.value!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canRoll && !widget.isRolling ? widget.onRoll : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle =
              widget.isRolling ? _controller.value * 2 * pi : 0.0;
          final scale =
              widget.isRolling ? 0.92 : (widget.canRoll ? 1.05 : 1.0);

          return Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(widget.size * 0.22),
                  border: Border.all(
                    color: widget.canRoll
                        ? widget.accentColor
                        : const Color(0xFFCBD5E1),
                    width: widget.canRoll ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                    if (widget.canRoll)
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.16),
                  child: _buildFace(_displayValue, widget.accentColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFace(int val, Color dotColor) {
    switch (val) {
      case 1:
        return Center(child: _dot(dotColor, large: true));
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
                alignment: Alignment.topLeft, child: _dot(dotColor)),
            Align(
                alignment: Alignment.bottomRight, child: _dot(dotColor)),
          ],
        );
      case 3:
        return Stack(children: [
          Align(alignment: Alignment.topLeft, child: _dot(dotColor)),
          Align(alignment: Alignment.center, child: _dot(dotColor)),
          Align(alignment: Alignment.bottomRight, child: _dot(dotColor)),
        ]);
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_dot(dotColor), _dot(dotColor)]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_dot(dotColor), _dot(dotColor)]),
          ],
        );
      case 5:
        return Stack(children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_dot(dotColor), _dot(dotColor)]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_dot(dotColor), _dot(dotColor)]),
            ],
          ),
          Align(alignment: Alignment.center, child: _dot(dotColor)),
        ]);
      case 6:
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_dot(dotColor), _dot(dotColor), _dot(dotColor)],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_dot(dotColor), _dot(dotColor), _dot(dotColor)],
            ),
          ],
        );
    }
  }

  Widget _dot(Color color, {bool large = false}) {
    final s = large ? widget.size * 0.22 : widget.size * 0.16;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 1,
            offset: const Offset(0.5, 0.5),
          ),
        ],
      ),
    );
  }
}
