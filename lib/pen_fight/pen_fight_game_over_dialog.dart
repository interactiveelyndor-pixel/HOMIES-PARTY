import 'package:flutter/material.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../widgets/winner_banner.dart';
import 'pen_fight_theme.dart';

/// Match conclusion dialog for Pen Fight.
/// Reuses the shared [WinnerBanner] overlay from lib/widgets as is without modifying it.
class PenFightGameOverDialog extends StatelessWidget {
  final String winnerName;
  final Color winnerColor;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const PenFightGameOverDialog({
    super.key,
    required this.winnerName,
    required this.winnerColor,
    required this.onPlayAgain,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: winnerColor.withValues(alpha: 0.5),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: winnerColor.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pen trophy avatar
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        winnerColor,
                        winnerColor.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: winnerColor.withValues(alpha: 0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🏆',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'MATCH VICTORY!',
                  style: AppTextStyles.title.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  '$winnerName has won 2 rounds and conquered the tabletop!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppPalette.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('pen_fight_home_button'),
                        onPressed: onHome,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Home',
                          style: AppTextStyles.body.copyWith(
                            color: AppPalette.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('pen_fight_play_again_button'),
                        onPressed: onPlayAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PenFightTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                          shadowColor: PenFightTheme.accentGlow,
                        ),
                        child: Text(
                          'Play Again',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Shared animated WinnerBanner overlay
            WinnerBanner(
              winnerName: winnerName,
              winnerColor: winnerColor,
            ),
          ],
        ),
      ),
    );
  }
}
