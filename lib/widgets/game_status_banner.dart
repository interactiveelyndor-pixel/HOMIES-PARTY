import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../theme/ludo_colors.dart';
import '../theme/ludo_theme.dart';

class GameStatusBanner extends StatelessWidget {
  final GameState state;

  const GameStatusBanner({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = LudoTheme.getPrimary(state.currentPlayer.color);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LudoColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
