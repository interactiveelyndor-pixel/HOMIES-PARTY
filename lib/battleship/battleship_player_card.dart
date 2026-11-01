import 'package:flutter/material.dart';
import 'battleship_colors.dart';
import 'battleship_models.dart';
import 'battleship_board.dart';

/// Status card showing player identity, active turn status, and surviving fleet.
class BattleshipPlayerCard extends StatelessWidget {
  final String title;
  final bool isCpu;
  final bool isActive;
  final BattleshipBoard board;
  final Color accentColor;

  const BattleshipPlayerCard({
    super.key,
    required this.title,
    this.isCpu = false,
    required this.isActive,
    required this.board,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BattleshipColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? accentColor
              : BattleshipColors.surfaceCardBorder,
          width: isActive ? 1.6 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive ? Colors.white : BattleshipColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isCpu) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: BattleshipColors.cpuColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: BattleshipColors.cpuColor.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'CPU',
                          style: TextStyle(
                            color: BattleshipColors.cpuColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'TURN',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Fleet icons / status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final type in ShipType.values)
                _buildShipIndicator(type, board.isShipSunk(type)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShipIndicator(ShipType type, bool isSunk) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < type.length; i++)
          Container(
            width: 4.5,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: isSunk
                  ? BattleshipColors.shipSunk
                  : accentColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        const SizedBox(width: 3),
      ],
    );
  }
}
