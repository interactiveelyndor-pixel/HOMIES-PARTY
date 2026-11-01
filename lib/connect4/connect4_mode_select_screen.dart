import 'package:flutter/material.dart';

import '../ui/app_back_button.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'connect4_game_screen.dart';

class ConnectFourModeSelectScreen extends StatelessWidget {
  const ConnectFourModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppBackButton(key: Key('c4_mode_back_button')),
                const SizedBox(height: 22),
                const Text('Connect Four', style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text(
                  'Line up four discs before your opponent does.',
                  style: AppTextStyles.subheading,
                ),
                const SizedBox(height: 26),
                _ModeCard(
                  key: const Key('c4_mode_friend'),
                  emoji: '🧑‍🤝‍🧑',
                  title: 'Play with a friend',
                  subtitle: 'Take turns on this phone',
                  colors: const [Color(0xFFFF5C8A), Color(0xFFFF8FB0)],
                  onTap: () => _open(context, vsComputer: false),
                ),
                const SizedBox(height: 18),
                _ModeCard(
                  key: const Key('c4_mode_computer'),
                  emoji: '🤖',
                  title: 'Play the computer',
                  subtitle: 'You are pink, it is yellow',
                  colors: const [Color(0xFFFFB400), Color(0xFFFFD23F)],
                  onTap: () => _open(context, vsComputer: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, {required bool vsComputer}) =>
      Navigator.of(context)
          .push(appPageRoute(ConnectFourGameScreen(vsComputer: vsComputer)));
}

class _ModeCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ModeCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        gradientColors: colors,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.heading.copyWith(
                      color: AppPalette.ink,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppPalette.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppPalette.ink,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}
