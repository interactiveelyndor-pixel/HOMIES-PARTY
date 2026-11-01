import 'package:flutter/material.dart';

/// Design palette for Homies: Party. A violet night sky with confetti colours,
/// taken from the game art, and ink outlines for the sticker look.
class AppPalette {
  AppPalette._();

  // --- Background & Canvas ---
  static const Color backgroundTop = Color(0xFF2B1466);
  static const Color backgroundBottom = Color(0xFF140A2E);
  static const Color backgroundElevated = Color(0xFF2A1B52);

  // --- Sticker kit ---
  static const Color ink = Color(0xFF140A2B); // outlines and hard shadows
  static const Color grape = Color(0xFF3B1E7A);
  static const Color panel = Color(0xFF34226B); // default card fill
  static const Color confetti = Color(0xFFFFD23F);
  static const Color candy = Color(0xFFFF5C8A);
  static const Color mint = Color(0xFF2EE6A6);
  static const Color sky = Color(0xFF3DB8FF);
  static const Color cream = Color(0xFFFFF8E7);

  /// One colour per player seat, in join order.
  static const List<Color> seatColors = [candy, sky, mint, confetti];

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  // --- Glass & Surfaces ---
  static const Color glassSurface = Color(0x1AFFFFFF);
  static const Color glassSurfaceHover = Color(0x28FFFFFF);
  static const Color glassBorder = Color(0x2EFFFFFF);
  static const Color glassBorderLight = Color(0x40FFFFFF);
  static const Color cardSurface = Color(0x14FFFFFF);

  // --- 4 Game Accent Colors ---
  // Ludo - sky
  static const Color ludo = Color(0xFF3DB8FF);
  static const Color ludoDark = Color(0xFF1F7AE0);
  static const Color ludoLight = Color(0xFF8BD5FF);
  static const Color ludoGlow = Color(0x403DB8FF);
  static const List<Color> ludoGradient = [Color(0xFF6D5BFF), Color(0xFF3DB8FF)];

  // Snakes & Ladders - mint
  static const Color snl = Color(0xFF2EE6A6);
  static const Color snlDark = Color(0xFF0FA873);
  static const Color snlLight = Color(0xFF8DF5CF);
  static const Color snlGlow = Color(0x402EE6A6);
  static const List<Color> snlGradient = [Color(0xFF16B67E), Color(0xFF2EE6A6)];

  // Carrom - tangerine
  static const Color carrom = Color(0xFFFFA62B);
  static const Color carromDark = Color(0xFFD97A00);
  static const Color carromLight = Color(0xFFFFC76B);
  static const Color carromGlow = Color(0x40FFA62B);
  static const List<Color> carromGradient = [Color(0xFFFF7A2B), Color(0xFFFFC23D)];

  // Battleship - lagoon
  static const Color battleship = Color(0xFF2BD0E6);
  static const Color battleshipDark = Color(0xFF0E8FB0);
  static const Color battleshipLight = Color(0xFF7BE7F5);
  static const Color battleshipGlow = Color(0x402BD0E6);
  static const List<Color> battleshipGradient = [Color(0xFF1E7BFF), Color(0xFF2BD0E6)];

  // --- Semantic Feedback ---
  static const Color success = Color(0xFF2EE6A6);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF5470);
  static const Color dangerDark = Color(0xFFC72F4B);
  static const Color dangerGlow = Color(0x40FF5470);
  static const List<Color> dangerGradient = [
    Color(0xFFD63A57),
    Color(0xFFFF5470),
  ];

  // --- Text Colors ---
  static const Color textPrimary = Color(0xFFFFF8E7);
  static const Color textSecondary = Color(0xFFD3C7F5);
  static const Color textMuted = Color(0xFFA596D6);
  static const Color textOnAccent = Color(0xFF140A2B);
}
