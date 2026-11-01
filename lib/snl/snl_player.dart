import 'package:flutter/material.dart';
import '../models/player_color.dart';
import 'snl_colors.dart';

/// A single player in a Snakes & Ladders game.
/// Each player has exactly ONE token on the 1-100 board.
/// [position] = 0 means the player has not yet entered the board.
/// [position] = 100 means the player has won.
@immutable
class SnlPlayer {
  final PlayerColor color;
  final String name;
  final int position; // 0 = off-board, 1..100 = active, 100 = won
  final bool hasWon;

  const SnlPlayer({
    required this.color,
    required this.name,
    this.position = 0,
    this.hasWon = false,
  });

  factory SnlPlayer.initial(PlayerColor color) {
    return SnlPlayer(
      color: color,
      name: color.displayName,
    );
  }

  /// Primary color for this player.
  Color get primaryColor => SnlColors.playerPrimary(color);

  /// Dark shade for token depth/shading.
  Color get darkColor => SnlColors.playerDark(color);

  /// Glow shade for active turn highlights.
  Color get glowColor => SnlColors.playerGlow(color);

  SnlPlayer copyWith({
    PlayerColor? color,
    String? name,
    int? position,
    bool? hasWon,
  }) {
    return SnlPlayer(
      color: color ?? this.color,
      name: name ?? this.name,
      position: position ?? this.position,
      hasWon: hasWon ?? this.hasWon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnlPlayer &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          name == other.name &&
          position == other.position &&
          hasWon == other.hasWon;

  @override
  int get hashCode => Object.hash(color, name, position, hasWon);

  @override
  String toString() => 'SnlPlayer($name, pos: $position)';
}
