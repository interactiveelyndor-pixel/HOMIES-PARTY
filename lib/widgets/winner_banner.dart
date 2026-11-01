import 'package:flutter/material.dart';

/// A self-animating "WINNER!" banner overlay.
///
/// Fades and scales in over ~900 ms, then holds at full opacity.
/// Rendered as [IgnorePointer] so existing buttons underneath remain
/// fully tappable and the replay / home flow is never blocked.
///
/// Usage: place inside a [Stack] on top of the winner dialog/screen.
class WinnerBanner extends StatefulWidget {
  /// Display name of the winning player.
  final String winnerName;

  /// Accent color representing the winner's team / token color.
  final Color winnerColor;

  const WinnerBanner({
    super.key,
    required this.winnerName,
    required this.winnerColor,
  });

  @override
  State<WinnerBanner> createState() => _WinnerBannerState();
}

class _WinnerBannerState extends State<WinnerBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );

    // Start immediately; single forward play, no repeat.
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- "WINNER!" headline ----
                Text(
                  'WINNER!',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: widget.winnerColor.withValues(alpha: 0.9),
                        blurRadius: 28,
                      ),
                      Shadow(
                        color: widget.winnerColor.withValues(alpha: 0.5),
                        blurRadius: 60,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // ---- Winner name pill ----
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.winnerColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: widget.winnerColor.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.winnerColor.withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.winnerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.winnerColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
