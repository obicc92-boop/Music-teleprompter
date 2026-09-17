import 'package:flutter/material.dart';

class AppColors {
  // Warm charcoal surfaces, darkest to lightest
  static const background = Color(0xFF0D0C0B);
  static const sidebar = Color(0xFF121110);
  static const surface = Color(0xFF171614);
  static const surfaceHover = Color(0xFF1A1917);
  static const surfaceElevated = Color(0xFF1D1B19);
  static const surfaceSelected = Color(0xFF211F1C);
  static const hairline = Color(0xFF26231F);
  static const border = Color(0xFF2E2A26);
  static const borderStrong = Color(0xFF3A342E);

  static const activeLine = Color(0xFFFFFFFF);
  static const inactiveLine = Color(0xFF555555);
  static const dimmedLine = Color(0xFF333333);
  static const accent = Color(0xFFFF6B35);
  static const accentText = Color(0xFFFF8A5C); // accent as text on dark
  static const accentSoft = Color(0x24FF6B35);
  static const accentGlow = Color(0x40FF6B35);
  static const onAccent = Color(0xFF140B06);
  static const danger = Color(0xFFFF8A7A);
  static const sectionHeader = Color(0xFF888888);
  static const controlBackground = Color(0xCC0D0C0B);
  static const sliderActive = Color(0xFFFF6B35);
  static const sliderInactive = Color(0xFF2E2A26);
  static const loopMarker = Color(0xFF4FC3F7);

  // App chrome (labels, icons, hints). Lyrics keep their own dimmed colours
  // above; these stay readable on the dark surfaces and under stage lights.
  static const textPrimary = Color(0xFFF3EFE9);
  static const uiText = Color(0xFFB3ADA5);
  static const uiHint = Color(0xFF8A847C);
  static const uiMuted = Color(0xFF77726B);
}

class AppTextStyles {
  /// Default lyrics typeface.
  static const String fontFamily = 'TeleprompterMono';

  /// Interface text.
  static const String ui = 'AppSans';

  /// Big titles, poster style.
  static const String display = 'TeleprompterOswald';

  /// Numbers that should line up: song numbers, times, speeds, keys.
  static const String mono = 'TeleprompterMono';

  /// Small spaced capitals above a heading or group ("SETLIST").
  static const eyebrow = TextStyle(
    fontFamily: ui,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.uiHint,
  );

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
  static const double speedStep = 0.05; // keys, on-screen buttons, phone remote

  static String speedLabel(double multiplier) =>
      '${multiplier.toStringAsFixed(2)}×';
}
