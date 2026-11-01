import 'package:flutter/foundation.dart';
import 'player_color.dart';
import 'token.dart';

@immutable
class Player {
  final PlayerColor color;
  final String name;
  final List<Token> tokens;
  final bool hasWon;
  final int finishRank;

  const Player({
    required this.color,
    required this.name,
    required this.tokens,
    this.hasWon = false,
    this.finishRank = 0,
  });

  factory Player.initial(PlayerColor color, {String? customName}) {
    return Player(
      color: color,
      name: customName ?? color.displayName,
      tokens: List.generate(
        4,
        (index) => Token(
          id: index,
          color: color,
          stepCount: -1,
          baseSlotIndex: index,
        ),
      ),
    );
  }

  int get homeCount => tokens.where((t) => t.isHome).length;
  int get baseCount => tokens.where((t) => t.isInBase).length;
  int get trackCount => tokens.where((t) => t.isOnTrack).length;
  bool get allHome => homeCount == 4;

  Player copyWith({
    PlayerColor? color,
    String? name,
    List<Token>? tokens,
    bool? hasWon,
    int? finishRank,
  }) {
    return Player(
      color: color ?? this.color,
      name: name ?? this.name,
      tokens: tokens ?? this.tokens,
      hasWon: hasWon ?? this.hasWon,
      finishRank: finishRank ?? this.finishRank,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          name == other.name &&
          listEquals(tokens, other.tokens) &&
          hasWon == other.hasWon &&
          finishRank == other.finishRank;

  @override
  int get hashCode => Object.hash(
        color,
        name,
        Object.hashAll(tokens),
        hasWon,
        finishRank,
      );

  @override
  String toString() =>
      'Player($name, color: ${color.displayName}, home: $homeCount/4)';
}
