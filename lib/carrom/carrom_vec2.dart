import 'dart:math' as math;

/// A lightweight 2D vector for pure Dart Carrom physics.
/// Has zero Flutter or dart:ui dependencies.
class CarromVec2 {
  final double x;
  final double y;

  const CarromVec2(this.x, this.y);

  static const CarromVec2 zero = CarromVec2(0.0, 0.0);

  CarromVec2 operator +(CarromVec2 other) =>
      CarromVec2(x + other.x, y + other.y);

  CarromVec2 operator -(CarromVec2 other) =>
      CarromVec2(x - other.x, y - other.y);

  CarromVec2 operator *(double scalar) =>
      CarromVec2(x * scalar, y * scalar);

  CarromVec2 operator /(double scalar) {
    if (scalar == 0.0) return CarromVec2.zero;
    return CarromVec2(x / scalar, y / scalar);
  }

  CarromVec2 operator -() => CarromVec2(-x, -y);

  double dot(CarromVec2 other) => x * other.x + y * other.y;

  double cross(CarromVec2 other) => x * other.y - y * other.x;

  double get lengthSquared => x * x + y * y;

  double get length => math.sqrt(lengthSquared);

  CarromVec2 normalized() {
    final len = length;
    if (len == 0.0) return CarromVec2.zero;
    return CarromVec2(x / len, y / len);
  }

  double distanceTo(CarromVec2 other) => (this - other).length;

  double distanceSquaredTo(CarromVec2 other) => (this - other).lengthSquared;

  CarromVec2 clampedLength(double maxLength) {
    final lenSq = lengthSquared;
    if (lenSq > maxLength * maxLength) {
      final len = math.sqrt(lenSq);
      if (len == 0.0) return CarromVec2.zero;
      return this * (maxLength / len);
    }
    return this;
  }

  CarromVec2 copyWith({double? x, double? y}) =>
      CarromVec2(x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarromVec2 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CarromVec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}
