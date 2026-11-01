import 'package:flutter/material.dart';
import '../models/player.dart';
import '../theme/ludo_colors.dart';
import '../theme/ludo_theme.dart';

class PlayerCardWidget extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;

  /// When true, a small "CPU" label is shown next to the player name.
  final bool isCpu;

  const PlayerCardWidget({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    this.isCpu = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = LudoTheme.getPrimary(player.color);
    final glow = LudoTheme.getGlow(player.color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? primary.withValues(alpha: 0.2)
            : const Color(0xFF1E293B).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn ? glow : Colors.white12,
          width: isCurrentTurn ? 2.0 : 1.0,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player color avatar / badge
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      color: isCurrentTurn ? Colors.white : LudoColors.textSecondary,
                      fontWeight:
                          isCurrentTurn ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (player.hasWon) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: LudoColors.starGold,
                      size: 14,
                    ),
                  ],
                  // ── CPU badge ──────────────────────────────────────────────
                  if (isCpu) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.blueGrey.withValues(alpha: 0.8),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'CPU',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              // Token status indicators
              Row(
                children: [
                  Text(
                    'Home: ${player.homeCount}/4',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
