import 'package:flutter/material.dart';
import 'carrom_colors.dart';
import 'carrom_models.dart';

/// Player status card displaying player identity, pocketed count,
/// Queen status, and active turn highlight.
class CarromPlayerCard extends StatelessWidget {
  final CarromPlayer player;
  final bool isCurrentTurn;
  final QueenStatus queenStatus;
  final CarromPlayerId? queenPocketedBy;

  const CarromPlayerCard({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    required this.queenStatus,
    required this.queenPocketedBy,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = player.assignedCoin == CoinType.white;
    final cardBorderColor = isCurrentTurn
        ? CarromColors.activeGlow
        : Colors.white.withValues(alpha: 0.08);

    final bool isQueenCovered = player.hasCoveredQueen;
    final bool isQueenPending = queenStatus == QueenStatus.pendingCover &&
        queenPocketedBy == player.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cardBorderColor,
          width: isCurrentTurn ? 2.0 : 1.0,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: CarromColors.activeGlow.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coin icon avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhite
                  ? CarromColors.whiteCoinBase
                  : CarromColors.blackCoinBase,
              border: Border.all(
                color: isWhite
                    ? CarromColors.whiteCoinRim
                    : CarromColors.blackCoinRim,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 3,
                ),
              ],
            ),
            child: isWhite
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CarromColors.whiteCoinRim,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),

          // Player name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        style: TextStyle(
                          color: isCurrentTurn
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${isWhite ? 'White' : 'Black'})',
                      style: TextStyle(
                        color: isWhite ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Score: ${player.score} pts',
                      style: TextStyle(
                        color: isCurrentTurn
                            ? CarromColors.activeGlow
                            : CarromColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${player.pocketedCount} coins)',
                      style: TextStyle(
                        color: isCurrentTurn
                            ? Colors.white70
                            : CarromColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isQueenCovered) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '👑 Covered',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (isQueenPending) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '👑 Pending',
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
