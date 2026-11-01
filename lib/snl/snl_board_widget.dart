import 'package:flutter/material.dart';
import 'snl_board_painter.dart';
import 'snl_colors.dart';
import 'snl_game_state.dart';
import 'snl_player.dart';

/// The 10×10 Snakes & Ladders board with animated tokens overlaid.
class SnlBoardWidget extends StatelessWidget {
  final SnlGameState state;

  const SnlBoardWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SnlColors.boardBorder, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Board (cells + snakes + ladders)
                CustomPaint(
                  size: Size(size, size),
                  painter: const SnlBoardPainter(),
                ),
                // Tokens
                ..._buildTokens(size),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTokens(double boardSize) {
    final cellSize = boardSize / 10;
    final widgets = <Widget>[];

    // Group players by cell to handle stacking
    final groups = <int, List<int>>{}; // cell → [playerIndex]
    for (int i = 0; i < state.players.length; i++) {
      final pos = state.players[i].position;
      if (pos > 0) {
        groups.putIfAbsent(pos, () => []).add(i);
      }
    }

    for (int i = 0; i < state.players.length; i++) {
      final player = state.players[i];
      if (player.position == 0) continue; // off-board

      final gridPos = snlCellToOffset(player.position);
      final groupForCell = groups[player.position] ?? [i];
      final indexInGroup = groupForCell.indexOf(i);
      final groupSize = groupForCell.length;

      final offset = _stackOffset(indexInGroup, groupSize);
      final tokenSize = groupSize == 1 ? cellSize * 0.62 : cellSize * 0.42;

      final left = gridPos.dx * cellSize + cellSize * offset.dx;
      final top = gridPos.dy * cellSize + cellSize * offset.dy;

      widgets.add(
        AnimatedPositioned(
          key: ValueKey('snl_token_$i'),
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          left: left,
          top: top,
          child: _buildTokenWidget(player, tokenSize),
        ),
      );
    }

    return widgets;
  }

  Offset _stackOffset(int index, int total) {
    if (total == 1) return const Offset(0.19, 0.19);
    if (total == 2) {
      return index == 0
          ? const Offset(0.05, 0.1)
          : const Offset(0.45, 0.45);
    }
    // 3 or 4: 2×2 grid
    final offsets = [
      const Offset(0.04, 0.04),
      const Offset(0.48, 0.04),
      const Offset(0.04, 0.48),
      const Offset(0.48, 0.48),
    ];
    return offsets[index % 4];
  }

  Widget _buildTokenWidget(SnlPlayer player, double size) {
    final primary = player.primaryColor;
    final dark = player.darkColor;
    final glow = player.glowColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
          BoxShadow(
            color: glow.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Body
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: size * 0.08),
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.85,
                colors: [primary, dark],
              ),
            ),
          ),
          // Inner jewel
          Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.88),
            ),
            child: Center(
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary,
                ),
              ),
            ),
          ),
          // Gloss
          Positioned(
            top: size * 0.1,
            left: size * 0.18,
            child: Container(
              width: size * 0.28,
              height: size * 0.13,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.all(
                    Radius.elliptical(size * 0.28, size * 0.13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
