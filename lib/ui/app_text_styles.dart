import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Type scale: Lilita One (chunky, friendly) for titles and buttons,
/// the system sans at a heavier weight for everything else.
class AppTextStyles {
  AppTextStyles._();

  /// Primary large page title.
  static const TextStyle title = TextStyle(
    color: AppPalette.textPrimary,
    fontFamily: 'LilitaOne',
    fontSize: 30,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.15,
  );

  /// Medium title / screen section header.
  static const TextStyle heading = TextStyle(
    color: AppPalette.textPrimary,
    fontFamily: 'LilitaOne',
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Subheading or card header.
  static const TextStyle subheading = TextStyle(
    color: AppPalette.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.35,
  );

  /// Standard readable body text.
  static const TextStyle body = TextStyle(
    color: AppPalette.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.45,
  );

  /// Emphasized body text.
  static const TextStyle bodyBold = TextStyle(
    color: AppPalette.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Button label typography with distinct tracking.
  static const TextStyle button = TextStyle(
    color: AppPalette.textOnAccent,
    fontFamily: 'LilitaOne',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.1,
  );

  /// Small metadata, hints, and secondary labels.
  static const TextStyle caption = TextStyle(
    color: AppPalette.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Micro badges and tag pills.
  static const TextStyle badge = TextStyle(
    color: AppPalette.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.1,
  );
}
