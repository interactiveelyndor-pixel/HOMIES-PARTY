import 'package:flutter/material.dart';
import '../models/board_coordinate.dart';
import '../models/board_path.dart';
import '../models/player_color.dart';
import '../theme/ludo_colors.dart';
import '../theme/ludo_theme.dart';

class BoardCellWidget extends StatelessWidget {
  final BoardCoordinate coord;
  final double size;

  const BoardCellWidget({
    super.key,
    required this.coord,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Check if star safe cell
    final isStar = BoardPath.starCoordinates.contains(coord);

    // 2. Check if player start cell
    PlayerColor? startColor;
    if (coord == const BoardCoordinate(6, 1)) startColor = PlayerColor.red;
    if (coord == const BoardCoordinate(1, 8)) startColor = PlayerColor.green;
    if (coord == const BoardCoordinate(8, 13)) startColor = PlayerColor.yellow;
    if (coord == const BoardCoordinate(13, 6)) startColor = PlayerColor.blue;

    // 3. Check if home stretch cell
    PlayerColor? homeStretchColor;
    for (final entry in BoardPath.homeStretches.entries) {
      if (entry.value.contains(coord)) {
        homeStretchColor = entry.key;
        break;
      }
    }

    Color cellColor = LudoColors.cellDefault;
    Widget? cellContent;

    if (startColor != null) {
      cellColor = LudoTheme.getPrimary(startColor);
      cellContent = Icon(
        Icons.play_arrow_rounded,
        size: size * 0.7,
        color: Colors.white,
      );
    } else if (isStar) {
      cellColor = const Color(0xFFFFF9C4);
      cellContent = Icon(
        Icons.star_rounded,
        size: size * 0.75,
        color: LudoColors.starDark,
      );
    } else if (homeStretchColor != null) {
      cellColor = LudoTheme.getPrimary(homeStretchColor);
      cellContent = Icon(
        _getHomeStretchArrow(homeStretchColor),
        size: size * 0.55,
        color: Colors.white.withValues(alpha: 0.9),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cellColor,
        border: Border.all(
          color: LudoColors.cellBorder,
          width: 0.6,
        ),
      ),
      child: cellContent != null ? Center(child: cellContent) : null,
    );
  }

  IconData _getHomeStretchArrow(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return Icons.arrow_forward_ios_rounded;
      case PlayerColor.green:
        return Icons.arrow_forward_ios_rounded;
      case PlayerColor.yellow:
        return Icons.arrow_back_ios_rounded;
      case PlayerColor.blue:
        return Icons.arrow_forward_ios_rounded;
    }
  }
}
