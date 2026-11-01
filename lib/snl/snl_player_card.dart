import 'package:flutter/material.dart';
import 'snl_colors.dart';
import 'snl_player.dart';

/// A compact status card showing a player's name, colour, and position.
class SnlPlayerCard extends StatelessWidget {
  final SnlPlayer player;
  final int? playerIndex;
  final bool isCurrentTurn;

  const SnlPlayerCard({
    super.key,
    required this.player,
    this.playerIndex,
    required this.isCurrentTurn,
  });

  @override
  Widget build(BuildContext context) {
    final primary = player.primaryColor;
    final glow = player.glowColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? primary.withValues(alpha: 0.18)
            : SnlColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentTurn
              ? primary.withValues(alpha: 0.7)
              : SnlColors.cardBorder,
          width: isCurrentTurn ? 1.8 : 1.0,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: glow.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Colour indicator
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: isCurrentTurn
                  ? [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.6),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                player.name[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    color: isCurrentTurn
                        ? SnlColors.textPrimary
                        : SnlColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  player.hasWon
                      ? '🏆 Won!'
                      : player.position == 0
                          ? 'Off board'
                          : 'Cell ${player.position}',
                  style: TextStyle(
                    color: player.hasWon
                        ? SnlColors.ladderAccent
                        : SnlColors.textSecondary,
                    fontSize: 9.5,
                    fontWeight:
                        player.hasWon ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (isCurrentTurn && !player.hasWon) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary,
                boxShadow: [
                  BoxShadow(
                      color: glow.withValues(alpha: 0.8), blurRadius: 4)
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
