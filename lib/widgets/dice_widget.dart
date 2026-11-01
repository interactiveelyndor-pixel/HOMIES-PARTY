import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player_color.dart';
import '../theme/ludo_theme.dart';

class DiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool canRoll;
  final PlayerColor playerColor;
  final VoidCallback? onRoll;
  final double size;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.canRoll,
    required this.playerColor,
    this.onRoll,
    this.size = 64.0,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _displayValue = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value ?? 1;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _animController.addListener(() {
      if (widget.isRolling) {
        setState(() {
          _displayValue = _random.nextInt(6) + 1;
        });
      }
    });

    if (widget.isRolling) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling != oldWidget.isRolling) {
      if (widget.isRolling) {
        _animController.repeat();
      } else {
        _animController.stop();
        _animController.reset();
        _displayValue = widget.value ?? 1;
      }
    } else if (!widget.isRolling && widget.value != null) {
      _displayValue = widget.value!;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = LudoTheme.getPrimary(widget.playerColor);
    final glowColor = LudoTheme.getGlow(widget.playerColor);

    return GestureDetector(
      onTap: widget.canRoll && !widget.isRolling ? widget.onRoll : null,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final rotationAngle = widget.isRolling
              ? _animController.value * 2 * pi
              : 0.0;
          final scale = widget.isRolling ? 0.92 : (widget.canRoll ? 1.05 : 1.0);

          return Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotationAngle,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(widget.size * 0.22),
                  border: Border.all(
                    color: widget.canRoll ? activeColor : const Color(0xFFCBD5E1),
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
                        color: glowColor.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.16),
                  child: _buildDiceFace(_displayValue, activeColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiceFace(int val, Color dotColor) {
    switch (val) {
      case 1:
        return Center(child: _buildDot(dotColor, isLarge: true));
      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: _buildDot(dotColor),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _buildDot(dotColor),
            ),
          ],
        );
      case 3:
        return Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: _buildDot(dotColor),
            ),
            Align(
              alignment: Alignment.center,
              child: _buildDot(dotColor),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _buildDot(dotColor),
            ),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildDot(dotColor), _buildDot(dotColor)],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_buildDot(dotColor), _buildDot(dotColor)],
            ),
          ],
        );
      case 5:
        return Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildDot(dotColor), _buildDot(dotColor)],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_buildDot(dotColor), _buildDot(dotColor)],
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: _buildDot(dotColor),
            ),
          ],
        );
      case 6:
      default:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDot(dotColor),
                _buildDot(dotColor),
                _buildDot(dotColor),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDot(dotColor),
                _buildDot(dotColor),
                _buildDot(dotColor),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildDot(Color color, {bool isLarge = false}) {
    final dotSize = isLarge ? widget.size * 0.22 : widget.size * 0.16;
    return Container(
      width: dotSize,
      height: dotSize,
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
