import 'package:flutter/foundation.dart';
import 'player_color.dart';

@immutable
class Token {
  final int id;
  final PlayerColor color;
  final int stepCount; // -1 = base, 0..55 = track/home stretch, 56 = HOME
  final int baseSlotIndex;

  const Token({
    required this.id,
    required this.color,
    this.stepCount = -1,
    required this.baseSlotIndex,
  });

  bool get isInBase => stepCount == -1;
  bool get isOnTrack => stepCount >= 0 && stepCount < 56;
  bool get isInHomeStretch => stepCount >= 51 && stepCount <= 55;
  bool get isHome => stepCount == 56;

  Token copyWith({
    int? id,
    PlayerColor? color,
    int? stepCount,
    int? baseSlotIndex,
  }) {
    return Token(
      id: id ?? this.id,
      color: color ?? this.color,
      stepCount: stepCount ?? this.stepCount,
      baseSlotIndex: baseSlotIndex ?? this.baseSlotIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          stepCount == other.stepCount &&
          baseSlotIndex == other.baseSlotIndex;

  @override
  int get hashCode => Object.hash(id, color, stepCount, baseSlotIndex);

  @override
  String toString() =>
      'Token(id: $id, color: ${color.displayName}, step: $stepCount)';
}
