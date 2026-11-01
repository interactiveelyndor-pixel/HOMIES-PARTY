import 'dart:math' as math;

/// A lightweight, pure Dart 2D vector for Pen Fight physics and AI calculations.
/// Completely decoupled from Flutter with zero UI or framework dependencies.
class PenFightVec2 {
  final double x;
  final double y;

  const PenFightVec2(this.x, this.y);

  static const PenFightVec2 zero = PenFightVec2(0.0, 0.0);

  PenFightVec2 operator +(PenFightVec2 other) =>
      PenFightVec2(x + other.x, y + other.y);

  PenFightVec2 operator -(PenFightVec2 other) =>
      PenFightVec2(x - other.x, y - other.y);

  PenFightVec2 operator *(double scalar) =>
      PenFightVec2(x * scalar, y * scalar);

  PenFightVec2 operator /(double scalar) {
    if (scalar == 0.0) return PenFightVec2.zero;
    return PenFightVec2(x / scalar, y / scalar);
  }

  PenFightVec2 operator -() => PenFightVec2(-x, -y);

  double dot(PenFightVec2 other) => x * other.x + y * other.y;

  double cross(PenFightVec2 other) => x * other.y - y * other.x;

  double get lengthSquared => x * x + y * y;

  double get length => math.sqrt(lengthSquared);

  PenFightVec2 normalized() {
    final len = length;
    if (len == 0.0) return PenFightVec2.zero;
    return PenFightVec2(x / len, y / len);
  }

  double distanceTo(PenFightVec2 other) => (this - other).length;

  double distanceSquaredTo(PenFightVec2 other) => (this - other).lengthSquared;

  PenFightVec2 clampedLength(double maxLength) {
    final lenSq = lengthSquared;
    if (lenSq > maxLength * maxLength) {
      final len = math.sqrt(lenSq);
      if (len == 0.0) return PenFightVec2.zero;
      return this * (maxLength / len);
    }
    return this;
  }

  PenFightVec2 copyWith({double? x, double? y}) =>
      PenFightVec2(x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PenFightVec2 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'PenFightVec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
