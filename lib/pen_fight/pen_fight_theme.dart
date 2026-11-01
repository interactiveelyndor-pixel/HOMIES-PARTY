import 'package:flutter/material.dart';

/// Centralized color and theme tokens for Pen Fight.
/// Kept isolated in lib/pen_fight/ to avoid touching core palette files.
class PenFightTheme {
  PenFightTheme._();

  // --- Pen Fight Primary Accent (Vivid Violet) ---
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentDark = Color(0xFF6D28D9);
  static const Color accentLight = Color(0xFFA78BFA);
  static const Color accentGlow = Color(0x408B5CF6);

  static const List<Color> accentGradient = [
    Color(0xFF581C87),
    Color(0xFF7C3AED),
  ];

  // --- Tabletop Aesthetics ---
  static const Color tableSurfaceTop = Color(0xFF1E293B);
  static const Color tableSurfaceBottom = Color(0xFF0F172A);
  static const Color tableBorder = Color(0xFF475569);
  static const Color tableBorderInner = Color(0xFF334155);
  static const Color tableGridLine = Color(0x12FFFFFF);

  // --- Player 1 Pen Styling (Cobalt / Cyan) ---
  static const Color p1PenBody = Color(0xFF0284C7);
  static const Color p1PenHighlight = Color(0xFF38BDF8);
  static const Color p1PenAccent = Color(0xFFE0F2FE);
  static const Color p1Glow = Color(0x400284C7);

  // --- Player 2 Pen Styling (Ruby / Coral) ---
  static const Color p2PenBody = Color(0xFFDC2626);
  static const Color p2PenHighlight = Color(0xFFF87171);
  static const Color p2PenAccent = Color(0xFFFEF2F2);
  static const Color p2Glow = Color(0x40DC2626);

  // --- Aim & Power Indicator Styling ---
  static const Color aimLineLow = Color(0xFF10B981);
  static const Color aimLineMid = Color(0xFFF59E0B);
  static const Color aimLineHigh = Color(0xFFEF4444);

  /// Computes aim line color interpolated by power fraction (0.0 to 1.0).
  static Color getPowerColor(double fraction) {
    if (fraction < 0.5) {
      return Color.lerp(aimLineLow, aimLineMid, fraction * 2.0)!;
    } else {
      return Color.lerp(aimLineMid, aimLineHigh, (fraction - 0.5) * 2.0)!;
    }
  }
}
