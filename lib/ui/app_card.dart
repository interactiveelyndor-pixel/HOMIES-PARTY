import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';

/// Sticker-style card: ink outline, hard offset shadow, gradient fill and a
/// quick squish on press. [glowColor] is kept for callers but no longer drawn.
class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;
  final Color? glowColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.gradientColors,
    this.glowColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(20.0),
    this.margin,
    this.borderRadius = 20.0,
    this.width,
    this.height,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  int _lastTapTime = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 95),
      reverseDuration: const Duration(milliseconds: 95),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 450) return;
    _lastTapTime = now;

    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradientColors ??
        const [AppPalette.panel, AppPalette.panel];

    final cardContent = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: widget.borderColor ?? AppPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: AppPalette.ink, offset: Offset(0, 5)),
        ],
      ),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return cardContent;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _animController.forward(),
        onTapUp: (_) => _animController.reverse(),
        onTapCancel: () => _animController.reverse(),
        onTap: _handleTap,
        child: cardContent,
      ),
    );
  }
}
