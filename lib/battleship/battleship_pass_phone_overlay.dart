import 'package:flutter/material.dart';
import 'battleship_colors.dart';
import 'battleship_models.dart';

/// Full-screen overlay used in multiplayer mode to pass the device between players.
/// Completely conceals the board and ships so players never see each other's fleets.
class BattleshipPassPhoneOverlay extends StatelessWidget {
  final BattleshipPlayerId targetPlayer;
  final VoidCallback onReady;

  const BattleshipPassPhoneOverlay({
    super.key,
    required this.targetPlayer,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final playerName =
        targetPlayer == BattleshipPlayerId.player1 ? 'Player 1' : 'Player 2';
    final playerColor = targetPlayer == BattleshipPlayerId.player1
        ? BattleshipColors.player1Color
        : BattleshipColors.player2Color;

    return Container(
      key: const Key('pass_phone_overlay'),
      color: BattleshipColors.backgroundBottom.withValues(alpha: 0.98),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: playerColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: playerColor.withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: playerColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.phonelink_ring_rounded,
                color: playerColor,
                size: 46,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Pass the phone to $playerName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your ships secret from your opponent!',
              style: TextStyle(
                color: BattleshipColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                key: const Key('pass_phone_ready_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: playerColor,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: onReady,
                child: const Text(
                  'Tap when ready',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
