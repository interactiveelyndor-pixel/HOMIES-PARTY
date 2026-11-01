import 'package:flutter/material.dart';
import '../ui/app_back_button.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'carrom_game_screen.dart';

/// Simple mode-selection screen shown after the user taps "Carrom" on the
/// home screen. Offers two choices:
///   • 2 Players — the unchanged human-vs-human game.
///   • vs Computer — human (White) vs CPU (Black).
class CarromModeSelectScreen extends StatelessWidget {
  const CarromModeSelectScreen({super.key});

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
              // Top bar with back arrow and title.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const AppBackButton(
                      key: Key('carrom_mode_back_button'),
                    ),
                    const Expanded(
                      child: Text(
                        'Classic Carrom',
                        style: AppTextStyles.heading,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Spacer to keep title centred.
                    const SizedBox(width: 42),
                  ],
                ),
              ),

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

                          // 2 Players card.
                          _CarromModeOptionCard(
                            key: const Key('carrom_mode_2players'),
                            emoji: '👥',
                            title: '2 Players',
                            subtitle: 'Human vs Human\nSame device',
                            gradientColors: const [
                              Color(0xFF1E40AF),
                              Color(0xFF3B82F6),
                            ],
                            glowColor: const Color(0x403B82F6),
                            onTap: () => Navigator.of(context).push(
                              appPageRoute(
                                const CarromGameScreen(vsComputer: false),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // vs Computer card.
                          _CarromModeOptionCard(
                            key: const Key('carrom_mode_vs_computer'),
                            emoji: '🤖',
                            title: 'vs Computer',
                            subtitle:
                                'You (White) vs CPU (Black)\nSingle player',
                            gradientColors: AppPalette.carromGradient,
                            glowColor: AppPalette.carromGlow,
                            onTap: () => Navigator.of(context).push(
                              appPageRoute(
                                const CarromGameScreen(vsComputer: true),
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

class _CarromModeOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _CarromModeOptionCard({
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
