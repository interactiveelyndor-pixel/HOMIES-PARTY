import 'package:flutter/foundation.dart';

@immutable
class BoardCoordinate {
  final int row;
  final int col;

  const BoardCoordinate(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardCoordinate &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'BoardCoordinate($row, $col)';
}
