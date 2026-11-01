import 'package:flutter/material.dart';

import '../catalog/game_catalog.dart';
import '../catalog/game_tile.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'online_lobby_screen.dart';

/// Home: the banner art with the wordmark, one big way to play with friends,
/// and every game in [GameCatalog] as a sticker.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Hero(),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Find a game. Find your people.',
                    style: AppTextStyles.heading.copyWith(
                      color: AppPalette.cream,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  key: const Key('home_online_lobby_fab'),
                  text: 'Play with friends',
                  width: double.infinity,
                  height: 58,
                  icon: const Icon(
                    Icons.celebration_rounded,
                    color: AppPalette.ink,
                  ),
                  onPressed: () =>
                      Navigator.of(context)
                          .push(appPageRoute(const OnlineLobbyScreen())),
                ),
                const SizedBox(height: 26),
                const Text('Pick a game', style: AppTextStyles.title),
                const SizedBox(height: 14),
                GameGrid(games: GameCatalog.all, keyPrefix: 'home'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner art with the wordmark sitting on it.
class _Hero extends StatelessWidget {
  const _Hero();

  static const _wordmark = TextStyle(
    fontFamily: 'Knewave',
    fontSize: 46,
    height: 1.0,
  );

  Widget _outlined(String text, Color fill) => Stack(
    children: [
      Text(
        text,
        style: _wordmark.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeJoin = StrokeJoin.round
            ..color = AppPalette.ink,
        ),
      ),
      Text(text, style: _wordmark.copyWith(color: fill)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Homies: Party. Find a game. Find your people.',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: AppPalette.ink, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/small/banner.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  cacheWidth: 1000,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppPalette.backgroundBottom.withValues(alpha: 0.92),
                        AppPalette.backgroundBottom.withValues(alpha: 0.0),
                      ],
                      stops: const [0.15, 0.75],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 190),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.rotate(
                          angle: -0.05,
                          child: _outlined('Homies', AppPalette.cream),
                        ),
                        Transform.rotate(
                          angle: -0.05,
                          child: _outlined('Party', AppPalette.confetti),
                        ),
                      ],
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
