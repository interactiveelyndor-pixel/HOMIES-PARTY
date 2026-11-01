import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';

/// Reusable circular, glassmorphic back button.
/// Includes press scale animation (<120ms), light haptics, and double-tap prevention.
class AppBackButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.size = 42.0,
    this.iconColor,
  });

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  int _lastTapTime = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 400) return;
    _lastTapTime = now;

    HapticFeedback.lightImpact();
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: Semantics(
        button: true,
        label: 'Back',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _animController.forward(),
          onTapUp: (_) => _animController.reverse(),
          onTapCancel: () => _animController.reverse(),
          onTap: _handleTap,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.glassSurface,
              border: Border.all(color: AppPalette.glassBorder, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(right: 2.0),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: widget.iconColor ?? AppPalette.textPrimary,
                size: widget.size * 0.44,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
