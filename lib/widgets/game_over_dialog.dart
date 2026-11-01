import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/ludo_colors.dart';
import '../theme/ludo_theme.dart';
import 'winner_banner.dart';

class GameOverDialog extends StatelessWidget {
  final Player winner;
  final VoidCallback onPlayAgain;
  final VoidCallback onChangeMode;

  const GameOverDialog({
    super.key,
    required this.winner,
    required this.onPlayAgain,
    required this.onChangeMode,
  });

  @override
  Widget build(BuildContext context) {
    final primary = LudoTheme.getPrimary(winner.color);
    final glow = LudoTheme.getGlow(winner.color);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: glow.withValues(alpha: 0.5),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.3),
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
            // Winner trophy icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primary, glow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'VICTORY!',
              style: TextStyle(
                color: LudoColors.starGold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${winner.name} has brought all 4 tokens HOME!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LudoColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onChangeMode,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Mode',
                      style: TextStyle(color: LudoColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Play Again',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
            ),
            // WinnerBanner overlay — IgnorePointer so buttons stay tappable
            WinnerBanner(
              winnerName: winner.name,
              winnerColor: primary,
            ),
          ],
        ),
      ),
    );
  }
}
