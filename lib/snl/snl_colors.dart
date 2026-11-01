import 'package:flutter/material.dart';
import '../models/player_color.dart';

/// Color palette for the Snakes & Ladders game.
/// Completely independent of LudoColors.
class SnlColors {
  SnlColors._();

  // App background
  static const Color backgroundTop = Color(0xFF0D1B2A);
  static const Color backgroundBottom = Color(0xFF030A12);

  // Board
  static const Color boardLight = Color(0xFFFFFBEA);
  static const Color boardDark = Color(0xFFE8D5A3);
  static const Color boardBorder = Color(0xFF2D3A4A);

  // Snake colors
  static const Color snakeBody = Color(0xFF16A34A);
  static const Color snakeHead = Color(0xFF15803D);
  static const Color snakeAccent = Color(0xFF4ADE80);
  static const Color snakeGlow = Color(0xFFBBF7D0);

  // Ladder colors
  static const Color ladderRung = Color(0xFFCA8A04);
  static const Color ladderSide = Color(0xFF92400E);
  static const Color ladderAccent = Color(0xFFFBBF24);
  static const Color ladderGlow = Color(0xFFFEF9C3);

  // Cell number text
  static const Color cellNumberDark = Color(0xFF374151);
  static const Color cellNumberLight = Color(0xFF6B7280);

  // UI
  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color cardBackground = Color(0x1AFFFFFF);
  static const Color cardBorder = Color(0x33FFFFFF);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentGlow = Color(0xFF7DD3FC);

  // Player colors (independent of LudoColors)
  static const Color red = Color(0xFFEF4444);
  static const Color redDark = Color(0xFFB91C1C);
  static const Color redGlow = Color(0xFFFCA5A5);

  static const Color green = Color(0xFF10B981);
  static const Color greenDark = Color(0xFF047857);
  static const Color greenGlow = Color(0xFF6EE7B7);

  static const Color yellow = Color(0xFFF59E0B);
  static const Color yellowDark = Color(0xFFB45309);
  static const Color yellowGlow = Color(0xFFFDE68A);

  static const Color blue = Color(0xFF3B82F6);
  static const Color blueDark = Color(0xFF1D4ED8);
  static const Color blueGlow = Color(0xFF93C5FD);

  /// Primary color for a player based on their PlayerColor enum.
  static Color playerPrimary(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return red;
      case PlayerColor.green:
        return green;
      case PlayerColor.yellow:
        return yellow;
      case PlayerColor.blue:
        return blue;
    }
  }

  /// Dark shade for token shading and depth.
  static Color playerDark(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return redDark;
      case PlayerColor.green:
        return greenDark;
      case PlayerColor.yellow:
        return yellowDark;
      case PlayerColor.blue:
        return blueDark;
    }
  }

  /// Glow color for active turn indicators and highlights.
  static Color playerGlow(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return redGlow;
      case PlayerColor.green:
        return greenGlow;
      case PlayerColor.yellow:
        return yellowGlow;
      case PlayerColor.blue:
        return blueGlow;
    }
  }
}
