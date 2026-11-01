import '../screens/game_details_screen.dart';
import '../screens/online_game_router.dart';

import 'dart:math' show cos, sin;

import 'package:flutter/material.dart';

import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'game_catalog.dart';

/// One game as a tilted sticker: art (or an emoji on the game's colour) on
/// top, name and player count on an ink strip below.
class GameTile extends StatelessWidget {
  final GameInfo game;
  final double tilt; // radians
  final VoidCallback onTap;

  const GameTile({
    super.key,
    required this.game,
    required this.onTap,
    this.tilt = 0,
  });

  String get _players => game.minPlayers == game.maxPlayers
      ? '${game.maxPlayers} players'
      : '${game.minPlayers}-${game.maxPlayers} players';

  bool get _online => onlineGames.any((g) => g.id == game.id);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Semantics(
        button: true,
        label:
            '${game.title}, $_players'
            '${game.hasComputerMode ? ', can play against the computer' : ''}'
            '${_online ? ', can be played online' : ''}',
        excludeSemantics: true,
        child: AppCard(
          onTap: onTap,
          gradientColors: game.gradient,
          padding: EdgeInsets.zero,
          borderRadius: 22,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1.08,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _art(),
                      if (_online)
                        Positioned(
                          key: Key('online_badge_${game.id}'),
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.mint,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppPalette.ink,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              'Online',
                              style: AppTextStyles.caption.copyWith(
                                color: AppPalette.ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: AppPalette.ink,
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
                  child: _info(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _art() => game.art != null
      ? Image.asset(game.art!, fit: BoxFit.cover, cacheWidth: 480)
      : CustomPaint(
          painter: const _SunburstPainter(),
          child: Center(
            child: Text(
              game.emoji,
              style: const TextStyle(
                fontSize: 64,
                shadows: [Shadow(color: AppPalette.ink, offset: Offset(0, 4))],
              ),
            ),
          ),
        );

  Widget _info() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          game.title,
          style: AppTextStyles.heading.copyWith(color: AppPalette.cream),
        ),
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          Icon(Icons.groups_rounded, size: 15, color: game.accent),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _players,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppPalette.textSecondary,
              ),
            ),
          ),
          if (game.hasComputerMode)
            const Icon(
              Icons.smart_toy_rounded,
              size: 16,
              color: AppPalette.textSecondary,
            ),
        ],
      ),
    ],
  );
}

/// Two-column wrap of [GameTile]s with a gentle alternating tilt. Not lazy,
/// so every tile exists for tests and screen readers.
class GameGrid extends StatelessWidget {
  final List<GameInfo> games;

  /// Tile keys are `'${keyPrefix}_${game.id}_card'`.
  final String keyPrefix;

  const GameGrid({super.key, required this.games, required this.keyPrefix});

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap + 4,
          children: [
            for (var i = 0; i < games.length; i++)
              SizedBox(
                width: w,
                child: GameTile(
                  key: Key('${keyPrefix}_${games[i].id}_card'),
                  game: games[i],
                  tilt: i.isEven ? -0.018 : 0.018,
                  onTap: () => Navigator.of(context)
                      .push(appPageRoute(GameDetailsScreen(game: games[i]))),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Soft alternating rays behind an emoji, like the rays in the card art.
class _SunburstPainter extends CustomPainter {
  const _SunburstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.16);
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a0 = (i * 2) * 3.14159265 / rays;
      final a1 = (i * 2 + 1) * 3.14159265 / rays;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + r * cos(a0), c.dy + r * sin(a0))
          ..lineTo(c.dx + r * cos(a1), c.dy + r * sin(a1))
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
