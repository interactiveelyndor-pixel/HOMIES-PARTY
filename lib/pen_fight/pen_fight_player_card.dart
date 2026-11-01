import 'package:flutter/material.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'pen_fight_config.dart';
import 'pen_fight_models.dart';
import 'pen_fight_theme.dart';

/// Player status card displaying player name, CPU badge if computer,
/// pen type, round wins, and active turn glow.
class PenFightPlayerCard extends StatelessWidget {
  final PenFightPlayerId id;
  final String name;
  final bool isCpu;
  final bool isCurrentTurn;
  final int score;
  final PenType? penType;

  const PenFightPlayerCard({
    super.key,
    required this.id,
    required this.name,
    required this.isCpu,
    required this.isCurrentTurn,
    required this.score,
    this.penType,
  });

  @override
  Widget build(BuildContext context) {
    final isP1 = id == PenFightPlayerId.player1;
    final penColor =
        isP1 ? PenFightTheme.p1PenHighlight : PenFightTheme.p2PenHighlight;
    final penBody = isP1 ? PenFightTheme.p1PenBody : PenFightTheme.p2PenBody;

    final borderColor =
        isCurrentTurn ? penColor : Colors.white.withValues(alpha: 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isCurrentTurn ? 2.0 : 1.0,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: penColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pen Avatar Indicator
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [penColor, penBody],
              ),
              boxShadow: [
                BoxShadow(
                  color: penBody.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🖊️',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Player Name & CPU Badge & Pen Type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isCpu) ...[
                      const SizedBox(width: 4),
                      Container(
                        key: const Key('pen_fight_cpu_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.0,
                        ),
                        decoration: BoxDecoration(
                          color: PenFightTheme.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: PenFightTheme.accentLight.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'CPU',
                          style: AppTextStyles.badge.copyWith(
                            fontSize: 8.0,
                            color: PenFightTheme.accentLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),

                // Round Wins & Pen Type Tag (Scales down gracefully with zero overflow)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Wins: $score',
                        style: AppTextStyles.caption.copyWith(
                          color: isCurrentTurn
                              ? AppPalette.textPrimary
                              : AppPalette.textSecondary,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ...List.generate(PenFightConfig.roundsToWin, (index) {
                        final isWon = index < score;
                        return Container(
                          margin: const EdgeInsets.only(left: 2),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isWon
                                ? penColor
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        );
                      }),
                      if (penType != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          '· ${penType!.displayName}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppPalette.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
