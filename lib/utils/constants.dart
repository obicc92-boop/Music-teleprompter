import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const surfaceElevated = Color(0xFF1E1E1E);
  static const activeLine = Color(0xFFFFFFFF);
  static const inactiveLine = Color(0xFF555555);
  static const dimmedLine = Color(0xFF333333);
  static const accent = Color(0xFFFF6B35);
  static const accentGlow = Color(0x40FF6B35);
  static const sectionHeader = Color(0xFF888888);
  static const controlBackground = Color(0xCC0A0A0A);
  static const sliderActive = Color(0xFFFF6B35);
  static const sliderInactive = Color(0xFF333333);
  static const loopMarker = Color(0xFF4FC3F7);
}

class AppTextStyles {
  static const String fontFamily = 'TeleprompterMono';

  static TextStyle activeLine(double fontSize, {String? displayFont}) =>
      TextStyle(
        fontFamily: displayFont ?? fontFamily,
        fontSize: fontSize,
        color: AppColors.activeLine,
        fontWeight: FontWeight.w700,
        height: 1.4,
        letterSpacing: 0.5,
      );

  static TextStyle inactiveLine(double fontSize, {String? displayFont}) =>
      TextStyle(
        fontFamily: displayFont ?? fontFamily,
        fontSize: fontSize,
        color: AppColors.inactiveLine,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  static TextStyle dimmedLine(double fontSize, {String? displayFont}) =>
      TextStyle(
        fontFamily: displayFont ?? fontFamily,
        fontSize: fontSize,
        color: AppColors.dimmedLine,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  static TextStyle sectionHeader(double fontSize, {String? displayFont}) =>
      TextStyle(
        fontFamily: displayFont ?? fontFamily,
        fontSize: fontSize * 0.6,
        color: AppColors.sectionHeader,
        fontWeight: FontWeight.w400,
        letterSpacing: 2.0,
      );
}

class DisplayFont {
  final String label;
  final String family;
  final String tagline;

  const DisplayFont({
    required this.label,
    required this.family,
    required this.tagline,
  });

  static const List<DisplayFont> options = [
    DisplayFont(label: 'Mono', family: 'TeleprompterMono', tagline: 'Precise'),
    DisplayFont(label: 'Inter', family: 'TeleprompterInter', tagline: 'Clean'),
    DisplayFont(label: 'Oswald', family: 'TeleprompterOswald', tagline: 'Bold'),
    DisplayFont(label: 'Serif', family: 'TeleprompterSerif', tagline: 'Warm'),
  ];

  static DisplayFont fromFamily(String family) =>
      options.firstWhere((f) => f.family == family, orElse: () => options.first);
}

class AppDimensions {
  static const double defaultFontSize = 52.0;
  static const double minFontSize = 24.0;
  static const double maxFontSize = 120.0;
  static const double lineSpacing = 24.0;
  static const double sectionSpacing = 48.0;
  static const double controlsHeight = 72.0;
  static const double controlsHideDelay = 3.0;
  static const double activeLineYOffset = 0.35;
}

class ScrollConstants {
  static const double minSpeedMultiplier = 0.2;
  static const double maxSpeedMultiplier = 3.0;
  static const double defaultSpeedMultiplier = 1.0;
  static const double pixelsPerSecondBase = 160.0;
  static const double keyboardSpeedStep = 0.05;
}
