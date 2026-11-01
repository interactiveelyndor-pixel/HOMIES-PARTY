import 'package:flutter/material.dart';
import '../models/player_color.dart';
import 'ludo_colors.dart';

class LudoTheme {
  LudoTheme._();

  static Color getPrimary(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return LudoColors.redPrimary;
      case PlayerColor.green:
        return LudoColors.greenPrimary;
      case PlayerColor.yellow:
        return LudoColors.yellowPrimary;
      case PlayerColor.blue:
        return LudoColors.bluePrimary;
    }
  }

  static Color getDark(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return LudoColors.redDark;
      case PlayerColor.green:
        return LudoColors.greenDark;
      case PlayerColor.yellow:
        return LudoColors.yellowDark;
      case PlayerColor.blue:
        return LudoColors.blueDark;
    }
  }

  static Color getLight(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return LudoColors.redLight;
      case PlayerColor.green:
        return LudoColors.greenLight;
      case PlayerColor.yellow:
        return LudoColors.yellowLight;
      case PlayerColor.blue:
        return LudoColors.blueLight;
    }
  }

  static Color getGlow(PlayerColor color) {
    switch (color) {
      case PlayerColor.red:
        return LudoColors.redGlow;
      case PlayerColor.green:
        return LudoColors.greenGlow;
      case PlayerColor.yellow:
        return LudoColors.yellowGlow;
      case PlayerColor.blue:
        return LudoColors.blueGlow;
    }
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: LudoColors.backgroundBottom,
      colorScheme: const ColorScheme.dark(
        primary: LudoColors.bluePrimary,
        surface: LudoColors.backgroundTop,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1B0F3D),
        indicatorColor: const Color(0xFFFFD23F),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(
            fontFamily: 'LilitaOne',
            fontSize: 13,
            color: Color(0xFFFFF8E7),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF140A2B)
                : const Color(0xFFD3C7F5),
          ),
        ),
      ),
    );
  }
}
