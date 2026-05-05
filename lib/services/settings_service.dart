import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AppSettings {
  final double fontSize;
  final double scrollSpeedMultiplier;
  final double voiceSensitivity;
  final double manualBpmOverride;
  final bool useManualBpm;
  final bool mirrorMode;
  final bool karaokeMode;
  final bool autoScrollOnVoice;

  const AppSettings({
    this.fontSize = AppDimensions.defaultFontSize,
    this.scrollSpeedMultiplier = ScrollConstants.defaultSpeedMultiplier,
    this.voiceSensitivity = AudioConstants.voiceEnergyThreshold,
    this.manualBpmOverride = AudioConstants.defaultBpm,
    this.useManualBpm = false,
    this.mirrorMode = false,
    this.karaokeMode = true,
    this.autoScrollOnVoice = true,
  });

  AppSettings copyWith({
    double? fontSize,
    double? scrollSpeedMultiplier,
    double? voiceSensitivity,
    double? manualBpmOverride,
    bool? useManualBpm,
    bool? mirrorMode,
    bool? karaokeMode,
    bool? autoScrollOnVoice,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      scrollSpeedMultiplier: scrollSpeedMultiplier ?? this.scrollSpeedMultiplier,
      voiceSensitivity: voiceSensitivity ?? this.voiceSensitivity,
      manualBpmOverride: manualBpmOverride ?? this.manualBpmOverride,
      useManualBpm: useManualBpm ?? this.useManualBpm,
      mirrorMode: mirrorMode ?? this.mirrorMode,
      karaokeMode: karaokeMode ?? this.karaokeMode,
      autoScrollOnVoice: autoScrollOnVoice ?? this.autoScrollOnVoice,
    );
  }
}

class SettingsService {
  static const _kFontSize = 'font_size';
  static const _kScrollSpeed = 'scroll_speed';
  static const _kVoiceSensitivity = 'voice_sensitivity';
  static const _kManualBpm = 'manual_bpm';
  static const _kUseManualBpm = 'use_manual_bpm';
  static const _kMirrorMode = 'mirror_mode';
  static const _kKaraokeMode = 'karaoke_mode';
  static const _kAutoScroll = 'auto_scroll_on_voice';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      fontSize: prefs.getDouble(_kFontSize) ?? AppDimensions.defaultFontSize,
      scrollSpeedMultiplier: prefs.getDouble(_kScrollSpeed) ?? ScrollConstants.defaultSpeedMultiplier,
      voiceSensitivity: prefs.getDouble(_kVoiceSensitivity) ?? AudioConstants.voiceEnergyThreshold,
      manualBpmOverride: prefs.getDouble(_kManualBpm) ?? AudioConstants.defaultBpm,
      useManualBpm: prefs.getBool(_kUseManualBpm) ?? false,
      mirrorMode: prefs.getBool(_kMirrorMode) ?? false,
      karaokeMode: prefs.getBool(_kKaraokeMode) ?? true,
      autoScrollOnVoice: prefs.getBool(_kAutoScroll) ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, settings.fontSize);
    await prefs.setDouble(_kScrollSpeed, settings.scrollSpeedMultiplier);
    await prefs.setDouble(_kVoiceSensitivity, settings.voiceSensitivity);
    await prefs.setDouble(_kManualBpm, settings.manualBpmOverride);
    await prefs.setBool(_kUseManualBpm, settings.useManualBpm);
    await prefs.setBool(_kMirrorMode, settings.mirrorMode);
    await prefs.setBool(_kKaraokeMode, settings.karaokeMode);
    await prefs.setBool(_kAutoScroll, settings.autoScrollOnVoice);
  }
}
