import 'package:flutter/material.dart';
import '../models/board_coordinate.dart';
import '../models/board_path.dart';
import '../models/game_state.dart';
import '../models/player_color.dart';
import '../models/token.dart';
import '../theme/ludo_colors.dart';
import 'base_quadrant_widget.dart';
import 'board_cell_widget.dart';
import 'center_home_widget.dart';
import 'token_widget.dart';

class LudoBoardWidget extends StatelessWidget {
  final GameState state;
  final ValueChanged<Token> onTokenTap;

  const LudoBoardWidget({
    super.key,
    required this.state,
    required this.onTokenTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cellSize = boardSize / 15.0;

        return Center(
          child: Container(
            width: boardSize,
            height: boardSize,
            decoration: BoxDecoration(
              color: LudoColors.boardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LudoColors.boardBorder,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // 1. Board Background Structure (Base Quadrants, Arms, Center)
                _buildBoardGrid(cellSize),

                // 2. Center Home
                Positioned(
                  left: 6 * cellSize,
                  top: 6 * cellSize,
                  child: CenterHomeWidget(size: 3 * cellSize),
                ),

                // 3. Tokens Layer
                ..._buildTokens(cellSize),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardGrid(double cellSize) {
    final activeColors = state.players.map((p) => p.color).toSet();

    return Stack(
      children: [
        // 4 Base Quadrants (6x6 each)
        // Red: Top-Left
        Positioned(
          left: 0,
          top: 0,
          child: BaseQuadrantWidget(
            color: PlayerColor.red,
            size: 6 * cellSize,
            isActive: activeColors.contains(PlayerColor.red),
          ),
        ),
        // Green: Top-Right
        Positioned(
          left: 9 * cellSize,
          top: 0,
          child: BaseQuadrantWidget(
            color: PlayerColor.green,
            size: 6 * cellSize,
            isActive: activeColors.contains(PlayerColor.green),
          ),
        ),
        // Yellow: Bottom-Right
        Positioned(
          left: 9 * cellSize,
          top: 9 * cellSize,
          child: BaseQuadrantWidget(
            color: PlayerColor.yellow,
            size: 6 * cellSize,
            isActive: activeColors.contains(PlayerColor.yellow),
          ),
        ),
        // Blue: Bottom-Left
        Positioned(
          left: 0,
          top: 9 * cellSize,
          child: BaseQuadrantWidget(
            color: PlayerColor.blue,
            size: 6 * cellSize,
            isActive: activeColors.contains(PlayerColor.blue),
          ),
        ),

        // Path arms cells (15x15 minus base corners and center)
        // Top arm: rows 0..5, cols 6..8
        for (int r = 0; r <= 5; r++)
          for (int c = 6; c <= 8; c++)
            _buildPositionedCell(r, c, cellSize),

        // Bottom arm: rows 9..14, cols 6..8
        for (int r = 9; r <= 14; r++)
          for (int c = 6; c <= 8; c++)
            _buildPositionedCell(r, c, cellSize),

        // Left arm: rows 6..8, cols 0..5
        for (int r = 6; r <= 8; r++)
          for (int c = 0; c <= 5; c++)
            _buildPositionedCell(r, c, cellSize),

        // Right arm: rows 6..8, cols 9..14
        for (int r = 6; r <= 8; r++)
          for (int c = 9; c <= 14; c++)
            _buildPositionedCell(r, c, cellSize),
      ],
    );
  }

  Widget _buildPositionedCell(int row, int col, double cellSize) {
    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      child: BoardCellWidget(
        coord: BoardCoordinate(row, col),
        size: cellSize,
      ),
    );
  }

  List<Widget> _buildTokens(double cellSize) {
    final widgets = <Widget>[];

    // Group active track tokens by coordinate to handle stacking
    final trackGroups = <BoardCoordinate, List<Token>>{};
    for (final player in state.players) {
      for (final token in player.tokens) {
        if (token.isOnTrack) {
          final coord = BoardPath.getCoordinate(player.color, token.stepCount);
          trackGroups.putIfAbsent(coord, () => []).add(token);
        }
      }
    }

    for (final player in state.players) {
      for (final token in player.tokens) {
        final isMovable = state.canSelectToken &&
            player.color == state.currentPlayer.color &&
            state.movableTokenIds.contains(token.id);

        double rowPos;
        double colPos;
        double tokenSize = cellSize * 0.82;

        if (token.isInBase) {
          final baseCoords = BoardPath.getBaseSlotCoordinates(player.color);
          final slot = baseCoords[token.baseSlotIndex];
          rowPos = slot.$1;
          colPos = slot.$2;
          tokenSize = cellSize * 0.72;
        } else if (token.isHome) {
          // Token is inside the Center Home goal
          tokenSize = cellSize * 0.58;
          switch (player.color) {
            case PlayerColor.red:
              rowPos = 7.0 + (token.id - 1.5) * 0.35;
              colPos = 6.4;
              break;
            case PlayerColor.green:
              rowPos = 6.4;
              colPos = 7.0 + (token.id - 1.5) * 0.35;
              break;
            case PlayerColor.yellow:
              rowPos = 7.0 + (token.id - 1.5) * 0.35;
              colPos = 7.6;
              break;
            case PlayerColor.blue:
              rowPos = 7.6;
              colPos = 7.0 + (token.id - 1.5) * 0.35;
              break;
          }
        } else {
          // On track or home stretch
          final coord = BoardPath.getCoordinate(player.color, token.stepCount);
          final group = trackGroups[coord] ?? [token];

          if (group.length == 1) {
            rowPos = coord.row + 0.1;
            colPos = coord.col + 0.1;
            tokenSize = cellSize * 0.8;
          } else {
            // Stacked tokens on same cell: arrange in mini offsets
            final indexInGroup = group.indexOf(token);
            tokenSize = cellSize * 0.52;
            final offset = _getStackedOffset(indexInGroup, group.length);
            rowPos = coord.row + offset.dy;
            colPos = coord.col + offset.dx;
          }
        }

        widgets.add(
          AnimatedPositioned(
            key: ValueKey('token_${player.color}_${token.id}'),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeInOutQuad,
            left: colPos * cellSize,
            top: rowPos * cellSize,
            child: TokenWidget(
              color: player.color,
              tokenId: token.id,
              size: tokenSize,
              isMovable: isMovable,
              onTap: isMovable ? () => onTokenTap(token) : null,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Offset _getStackedOffset(int index, int total) {
    if (total == 2) {
      return index == 0
          ? const Offset(0.08, 0.08)
          : const Offset(0.40, 0.40);
    }
    // 3 or 4 tokens: 2x2 grid in cell
    switch (index % 4) {
      case 0:
        return const Offset(0.05, 0.05);
      case 1:
        return const Offset(0.45, 0.05);
      case 2:
        return const Offset(0.05, 0.45);
      case 3:
      default:
        return const Offset(0.45, 0.45);
    }
  }
}
