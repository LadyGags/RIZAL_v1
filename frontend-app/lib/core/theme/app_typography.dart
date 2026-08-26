import 'package:flutter/material.dart';

/// Type system — **Manrope** for UI, **JetBrains Mono** for data/IDs/timestamps.
/// Both are bundled as asset fonts (see `pubspec.yaml`) so they render reliably
/// offline and in release builds — no runtime font fetching.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Manrope';
  static const String monoFamily = 'JetBrainsMono';

  static const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

  /// Manrope text theme tinted with [ink].
  static TextTheme textTheme(Color ink) {
    TextStyle s(double size, double lineHeight, FontWeight w) => TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          height: lineHeight / size,
          fontWeight: w,
          // Manrope is a variable font — drive its weight axis explicitly, else
          // every weight renders at the thin default (looked super-thin before).
          fontVariations: [FontVariation('wght', w.value.toDouble())],
          color: ink,
        );

    return TextTheme(
      displaySmall: s(32, 40, FontWeight.w800), // display
      headlineMedium: s(24, 30, FontWeight.w700), // title
      headlineSmall: s(20, 26, FontWeight.w700), // headline
      titleLarge: s(17, 26, FontWeight.w600), // bodyL / card title
      bodyLarge: s(16, 24, FontWeight.w500),
      bodyMedium: s(15, 22, FontWeight.w400),
      labelLarge: s(14, 18, FontWeight.w600),
      labelMedium: s(13, 16, FontWeight.w600), // label
      bodySmall: s(12, 16, FontWeight.w500), // caption
    ).apply(bodyColor: ink, displayColor: ink);
  }

  /// Monospace style for numbers, IDs, timestamps, codes (tabular figures).
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        fontFeatures: _tnum,
      );

  /// Manrope **UI** text — for anywhere a custom widget composes its own
  /// label/heading instead of using `textTheme`. Drives the variable-font
  /// weight axis (Manrope renders thin without `fontVariations`).
  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
}
