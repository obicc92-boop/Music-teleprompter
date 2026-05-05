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
  static const voiceActive = Color(0xFF4CAF50);
  static const voiceInactive = Color(0xFF555555);
  static const beatFlash = Color(0xFFFFD700);
  static const sectionHeader = Color(0xFF888888);
  static const controlBackground = Color(0xCC0A0A0A);
  static const sliderActive = Color(0xFFFF6B35);
  static const sliderInactive = Color(0xFF333333);
  static const highlightKaraoke = Color(0xFFFFD700);
  static const loopMarker = Color(0xFF4FC3F7);
}

class AppTextStyles {
  static const String fontFamily = 'TeleprompterMono';

  static TextStyle activeLine(double fontSize) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: AppColors.activeLine,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static TextStyle inactiveLine(double fontSize) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: AppColors.inactiveLine,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle dimmedLine(double fontSize) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: AppColors.dimmedLine,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle sectionHeader(double fontSize) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize * 0.6,
    color: AppColors.sectionHeader,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.0,
  );

  static TextStyle karaokePast(double fontSize) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    color: AppColors.highlightKaraoke,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );
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

class AudioConstants {
  static const int sampleRate = 44100;
  static const int fftWindowSize = 1024;
  static const int hopSize = 512;
  static const double minBpm = 60.0;
  static const double maxBpm = 200.0;
  static const double defaultBpm = 120.0;
  static const double voiceEnergyThreshold = 0.015;
  static const double beatEnergyThreshold = 1.8;
  static const int bpmAverageWindow = 8;
  static const double voiceDebounceMs = 300.0;
  static const int micBufferSize = 4096;
}

class ScrollConstants {
  static const double minSpeedMultiplier = 0.1;
  static const double maxSpeedMultiplier = 5.0;
  static const double defaultSpeedMultiplier = 1.0;
  static const double voiceSpeedBoost = 1.15;
  static const double silenceSpeedReduction = 0.3;
  static const double speedSmoothingFactor = 0.08;
  static const double pixelsPerSecondBase = 80.0;
}
