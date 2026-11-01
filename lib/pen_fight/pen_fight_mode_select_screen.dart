import 'package:flutter/material.dart';
import '../ui/app_back_button.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'pen_fight_pen_select_screen.dart';
import 'pen_fight_theme.dart';

/// Mode selection screen shown after tapping "Pen Fight" on the home screen.
/// Offers two choices:
///   • Play with Friend — 2 humans on 1 phone (Pass & play).
///   • vs Computer — Human (Player 1) vs CPU (Player 2).
class PenFightModeSelectScreen extends StatelessWidget {
  const PenFightModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with back arrow and title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const AppBackButton(
                      key: Key('pen_fight_mode_back_button'),
                    ),
                    Expanded(
                      child: Text(
                        'Pen Fight',
                        style: AppTextStyles.heading.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),

              // Mode Cards Container
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.glassSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppPalette.glassBorder,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'SELECT MODE',
                              style: AppTextStyles.badge.copyWith(
                                color: AppPalette.textSecondary,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 1. Play with Friend (2 Players)
                          _PenFightModeOptionCard(
                            key: const Key('pen_fight_mode_2players'),
                            emoji: '👥',
                            title: 'Play with Friend',
                            subtitle:
                                '2 players · Same device\nTurn-by-turn tabletop flick duel',
                            gradientColors: const [
                              Color(0xFF1E40AF),
                              Color(0xFF3B82F6),
                            ],
                            glowColor: const Color(0x403B82F6),
                            onTap: () => Navigator.of(context).push(
                              appPageRoute(
                                const PenFightPenSelectScreen(vsComputer: false),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. vs Computer
                          _PenFightModeOptionCard(
                            key: const Key('pen_fight_mode_vs_computer'),
                            emoji: '🤖',
                            title: 'vs Computer',
                            subtitle:
                                'Single player vs CPU\nTest your precision against the bot',
                            gradientColors: PenFightTheme.accentGradient,
                            glowColor: PenFightTheme.accentGlow,
                            onTap: () => Navigator.of(context).push(
                              appPageRoute(
                                const PenFightPenSelectScreen(vsComputer: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenFightModeOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _PenFightModeOptionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      gradientColors: gradientColors,
      glowColor: glowColor,
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.heading.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}
