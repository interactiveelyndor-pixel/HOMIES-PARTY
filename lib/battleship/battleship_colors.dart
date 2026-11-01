import 'package:flutter/material.dart';

/// Centralized color palette and styling constants for Battleship.
/// Features a calm, soft naval radar aesthetic with thin lines and subtle highlights.
class BattleshipColors {
  BattleshipColors._();

  // Background gradients - soft, calm dark blue/slate
  static const Color backgroundTop = Color(0xFF0B132B);
  static const Color backgroundBottom = Color(0xFF070B18);
  static const Color surfaceCard = Color(0xFF131D33);
  static const Color surfaceCardBorder = Color(0xFF22304C);

  // Radar / Ocean Grid
  static const Color gridBackground = Color(0xFF0D182A);
  static const Color gridCell = Color(0xFF132238);
  static const Color gridCellBorder = Color(0xFF1C2F4D);
  static const Color gridCellHover = Color(0xFF1D3B6A);

  // Ship Colors
  static const Color shipHull = Color(0xFF38BDF8);
  static const Color shipHullDark = Color(0xFF0284C7);
  static const Color shipBorder = Color(0xFF7DD3FC);
  static const Color shipSunk = Color(0xFF7F1D1D);

  // Shot feedback
  static const Color hitColor = Color(0xFFEF4444);
  static const Color hitGlow = Color(0xFFF97316);
  static const Color missColor = Color(0xFF38BDF8);
  static const Color missDot = Color(0xFF7DD3FC);

  // Player & UI Accents
  static const Color player1Color = Color(0xFF38BDF8);
  static const Color player2Color = Color(0xFFF59E0B);
  static const Color cpuColor = Color(0xFFEF4444);
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentGreen = Color(0xFF10B981);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}
