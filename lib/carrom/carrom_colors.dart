import 'package:flutter/material.dart';

/// Design tokens and rich color palettes for Carrom board and pieces.
class CarromColors {
  CarromColors._();

  // --- Frame & Playing Surface ---
  /// Rich dark mahogany outer frame.
  static const Color frameDark = Color(0xFF2C1810);
  static const Color frameLight = Color(0xFF4A2A1B);
  static const Color frameBorder = Color(0xFF1A0E0A);

  /// Natural wood / birch veneer playing surface.
  static const Color surfaceLight = Color(0xFFF3DEBA);
  static const Color surfaceDark = Color(0xFFE4C99F);
  static const Color surfaceGrain = Color(0xFFD4B384);

  /// Pockets.
  static const Color pocketCavity = Color(0xFF121212);
  static const Color pocketRim = Color(0xFF333333);
  static const Color pocketNet = Color(0xFF1E1E1E);

  /// Board Markings (inlays).
  static const Color markingPrimary = Color(0xFF8B2500); // Rust red
  static const Color markingSecondary = Color(0xFF3E2723); // Dark wood line
  static const Color markingAccent = Color(0xFFD32F2F);

  // --- Coins ---
  /// White / Ivory Carrom men.
  static const Color whiteCoinBase = Color(0xFFFFFBF0);
  static const Color whiteCoinShadow = Color(0xFFD6CCA9);
  static const Color whiteCoinRim = Color(0xFFB5A882);

  /// Black / Dark Ebony Carrom men.
  static const Color blackCoinBase = Color(0xFF2B2B2B);
  static const Color blackCoinShadow = Color(0xFF141414);
  static const Color blackCoinRim = Color(0xFF424242);

  /// Red Queen.
  static const Color queenBase = Color(0xFFE52525);
  static const Color queenShadow = Color(0xFF8E1111);
  static const Color queenRim = Color(0xFFFF6666);
  static const Color queenGoldPip = Color(0xFFFFD700);

  /// Striker (Ivory pearl with electric cyan accent).
  static const Color strikerBase = Color(0xFFF7F7F7);
  static const Color strikerShadow = Color(0xFFB0BEC5);
  static const Color strikerRim = Color(0xFF78909C);
  static const Color strikerAccent = Color(0xFF00ACC1);

  // --- UI Elements ---
  static const Color background = Color(0xFF0F172A);
  static const Color backgroundCard = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color activeGlow = Color(0xFF38BDF8);
  static const Color aimLine = Color(0xFFFFEB3B);
  static const Color powerLow = Color(0xFF4CAF50);
  static const Color powerMed = Color(0xFFFF9800);
  static const Color powerHigh = Color(0xFFF44336);
}
