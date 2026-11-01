import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';

/// Style variants available for [AppButton].
enum AppButtonVariant {
  primary,
  secondary,
  danger,
}

/// Reusable premium modern button.
/// Includes quick press scale animation (<120ms), subtle layered shadow,
/// double-tap prevention debounce, optional loading spinner, and haptic feedback.
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;
  final List<Color>? customGradient;
  final Color? customGlow;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = 52.0,
    this.customGradient,
    this.customGlow,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  int _lastTapTime = 0;

  bool get _isClickable =>
      widget.enabled && !widget.isLoading && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (_isClickable) {
      _animController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isClickable) {
      _animController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isClickable) {
      _animController.reverse();
    }
  }

  void _handleTap() {
    if (!_isClickable) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Double-tap safe throttle (500 ms)
    if (now - _lastTapTime < 500) {
      return;
    }
    _lastTapTime = now;

    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = _isClickable;

    // Decoration based on variant and state
    final BoxDecoration decoration = _buildDecoration(isClickable);
    final TextStyle textStyle = _buildTextStyle(isClickable);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.text,
            style: textStyle,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ],
    );

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
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
          decoration: decoration,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  static const _hardShadow = [BoxShadow(color: AppPalette.ink, offset: Offset(0, 4))];

  BoxDecoration _sticker(List<Color> colors) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.ink, width: 3),
        boxShadow: _hardShadow,
      );

  List<Color> get _fill {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return widget.customGradient ??
            const [AppPalette.confetti, Color(0xFFFFB400)];
      case AppButtonVariant.danger:
        return widget.customGradient ?? AppPalette.dangerGradient;
      case AppButtonVariant.secondary:
        return const [AppPalette.grape, AppPalette.panel];
    }
  }

  BoxDecoration _buildDecoration(bool isClickable) {
    if (!isClickable) {
      return BoxDecoration(
        color: AppPalette.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.ink.withValues(alpha: 0.6), width: 3),
      );
    }
    return _sticker(_fill);
  }

  TextStyle _buildTextStyle(bool isClickable) {
    if (!isClickable) {
      return AppTextStyles.button.copyWith(color: AppPalette.textMuted);
    }
    // Dark ink on light fills, cream on dark fills, so labels stay readable
    // whatever gradient a caller passes in.
    final light = _fill.first.computeLuminance() > 0.3;
    return AppTextStyles.button.copyWith(
      color: light ? AppPalette.ink : AppPalette.cream,
    );
  }
}
