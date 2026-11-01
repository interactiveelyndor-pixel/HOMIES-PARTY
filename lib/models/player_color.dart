import 'package:flutter/material.dart';

enum PlayerColor {
  red,
  green,
  yellow,
  blue;

  String get displayName {
    switch (this) {
      case PlayerColor.red:
        return 'Red';
      case PlayerColor.green:
        return 'Green';
      case PlayerColor.yellow:
        return 'Yellow';
      case PlayerColor.blue:
        return 'Blue';
    }
  }

  Color get primaryColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFE53935);
      case PlayerColor.green:
        return const Color(0xFF2E7D32);
      case PlayerColor.yellow:
        return const Color(0xFFF9A825);
      case PlayerColor.blue:
        return const Color(0xFF1565C0);
    }
  }

  Color get darkColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFB71C1C);
      case PlayerColor.green:
        return const Color(0xFF1B5E20);
      case PlayerColor.yellow:
        return const Color(0xFFF57F17);
      case PlayerColor.blue:
        return const Color(0xFF0D47A1);
    }
  }

  Color get lightColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFFFEBEE);
      case PlayerColor.green:
        return const Color(0xFFE8F5E9);
      case PlayerColor.yellow:
        return const Color(0xFFFFFDE7);
      case PlayerColor.blue:
        return const Color(0xFFE3F2FD);
    }
  }

  Color get glowColor {
    switch (this) {
      case PlayerColor.red:
        return const Color(0xFFFF5252);
      case PlayerColor.green:
        return const Color(0xFF69F0AE);
      case PlayerColor.yellow:
        return const Color(0xFFFFD740);
      case PlayerColor.blue:
        return const Color(0xFF448AFF);
    }
  }
}
