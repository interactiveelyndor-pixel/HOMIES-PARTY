import 'package:flutter/material.dart';

import '../catalog/game_catalog.dart';
import '../ui/app_back_button.dart';
import '../ui/app_button.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'online_game_router.dart';
import 'online_lobby_screen.dart';

/// What a game is, how it is played and how to start it. Sits between the
/// game list and the game itself.
class GameDetailsScreen extends StatelessWidget {
  final GameInfo game;
  const GameDetailsScreen({super.key, required this.game});

  bool get _hasOnline => onlineGames.any((g) => g.id == game.id);

  String get _players => game.minPlayers == game.maxPlayers
      ? '${game.maxPlayers} players'
      : '${game.minPlayers}-${game.maxPlayers} players';

  List<String> get _modes => [
    'Pass and play on one phone',
    if (game.hasComputerMode) 'Play against the computer',
    if (_hasOnline) 'Online with friends (private room)',
  ];

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [const AppBackButton()]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: game.accent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppPalette.ink, width: 3),
                          ),
                          child: game.art == null
                              ? Text(
                                  game.emoji,
                                  style: const TextStyle(fontSize: 36),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    game.art!,
                                    fit: BoxFit.cover,
                                    width: 66,
                                    height: 66,
                                    errorBuilder: (_, _, _) => Text(
                                      game.emoji,
                                      style: const TextStyle(fontSize: 36),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.title,
                                key: const Key('details_title'),
                                style: AppTextStyles.title,
                              ),
                              Text(game.badge, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          key: const Key('details_players'),
                          avatar: const Icon(Icons.group_rounded, size: 18),
                          label: Text(_players),
                        ),
                        Chip(
                          key: const Key('details_duration'),
                          avatar: const Icon(Icons.timer_outlined, size: 18),
                          label: Text(game.duration),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('How to play', style: AppTextStyles.heading),
                    const SizedBox(height: 6),
                    for (var i = 0; i < game.rules.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${i + 1}. ${game.rules[i]}',
                          style: AppTextStyles.body,
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text('Ways to play', style: AppTextStyles.heading),
                    const SizedBox(height: 6),
                    for (final m in _modes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $m', style: AppTextStyles.body),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  children: [
                    AppButton(
                      key: const Key('details_play'),
                      text: 'Play',
                      width: double.infinity,
                      onPressed: () => Navigator.of(
                        context,
                      ).push(appPageRoute(game.launch())),
                    ),
                    if (_hasOnline) ...[
                      const SizedBox(height: 10),
                      AppButton(
                        key: const Key('details_online'),
                        text: 'Play online with friends',
                        variant: AppButtonVariant.secondary,
                        width: double.infinity,
                        onPressed: () => Navigator.of(context).push(
                          appPageRoute(OnlineLobbyScreen(initialGame: game.id)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
