import 'package:flutter/material.dart';
import '../widgets/winner_banner.dart';
import 'battleship_colors.dart';

/// Result dialog displayed when a Battleship match ends.
/// Reuses the shared [WinnerBanner] overlay from lib/widgets as is without modifying it.
class BattleshipGameOverDialog extends StatelessWidget {
  final String winnerName;
  final Color winnerColor;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const BattleshipGameOverDialog({
    super.key,
    required this.winnerName,
    required this.winnerColor,
    required this.onRetry,
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
          color: BattleshipColors.surfaceCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: winnerColor.withValues(alpha: 0.5),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: winnerColor.withValues(alpha: 0.3),
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
                // Naval trophy / anchor icon
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
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'NAVAL VICTORY!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$winnerName has eliminated the entire enemy fleet!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BattleshipColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('battleship_home_button'),
                        onPressed: onHome,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Home',
                          style: TextStyle(
                            color: BattleshipColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('battleship_retry_button'),
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: winnerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
