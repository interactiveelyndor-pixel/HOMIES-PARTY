import 'package:flutter/material.dart';

import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import 'connect4_logic.dart';

const c4Player1 = AppPalette.candy;
const c4Player2 = AppPalette.confetti;
const c4Hole = Color(0xFF1B0F3D);

class ConnectFourStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool live;
  const ConnectFourStatusPill({
    super.key,
    required this.text,
    required this.color,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppPalette.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: AppPalette.ink, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.ink, width: 2.5),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: Text(text, style: AppTextStyles.heading)),
          ],
        ),
      ),
    );
  }
}

class ConnectFourBoard extends StatelessWidget {
  final ConnectFourGame game;
  final int moves;
  final void Function(int col) onColumn;
  const ConnectFourBoard({
    super.key,
    required this.game,
    required this.moves,
    required this.onColumn,
  });

  @override
  Widget build(BuildContext context) {
    final win = {for (final c in game.winningCells) c};
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppPalette.sky,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: AppPalette.ink, offset: Offset(0, 6)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Fit the grid in whichever of width or height is tighter.
          final cell = (box.maxWidth / ConnectFourGame.cols).clamp(
            0.0,
            box.maxHeight / ConnectFourGame.rows,
          );
          return Center(
            child: SizedBox(
              width: cell * ConnectFourGame.cols,
              height: cell * ConnectFourGame.rows,
              child: Row(
                children: [
                  for (var c = 0; c < ConnectFourGame.cols; c++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Drop a disc in column ${c + 1}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: Key('c4_column_$c'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onColumn(c),
                          child: Column(
                            children: [
                              for (var r = 0; r < ConnectFourGame.rows; r++)
                                SizedBox(
                                  width: cell,
                                  height: cell,
                                  child: _Cell(
                                    owner: game.board[r][c],
                                    falls: game.lastMove == (r, c),
                                    dropRows: r + 1,
                                    moves: moves,
                                    highlight: win.contains((r, c)),
                                    fallDistance: (r + 1) * cell,
                                    key: game.board[r][c] == 0
                                        ? null
                                        : Key('c4_disc_${r}_$c'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int owner;
  final bool falls;
  final int dropRows;
  final int moves;
  final bool highlight;
  final double fallDistance;
  const _Cell({
    super.key,
    required this.owner,
    required this.falls,
    required this.dropRows,
    required this.moves,
    required this.highlight,
    required this.fallDistance,
  });

  @override
  Widget build(BuildContext context) {
    final hole = Container(
      margin: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: c4Hole, shape: BoxShape.circle),
    );
    if (owner == 0) return hole;

    Widget disc = Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: owner == 1 ? c4Player1 : c4Player2,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight ? AppPalette.cream : AppPalette.ink,
          width: highlight ? 4 : 2.5,
        ),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.18),
                width: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
    if (!falls || MediaQuery.disableAnimationsOf(context)) {
      return Stack(children: [hole, disc]);
    }

    // Only the newest disc drops, with a little bounce.
    disc = TweenAnimationBuilder<double>(
      key: ValueKey('drop$moves'),
      tween: Tween(begin: -fallDistance, end: 0),
      duration: Duration(milliseconds: 280 + 70 * dropRows),
      curve: Curves.bounceOut,
      builder: (_, dy, child) =>
          Transform.translate(offset: Offset(0, dy), child: child),
      child: disc,
    );
    return Stack(clipBehavior: Clip.none, children: [hole, disc]);
  }
}
