import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AppSettings {
  final double fontSize;
  final double scrollSpeedMultiplier;
  final double voiceSensitivity;
  final double manualBpmOverride;
  final bool useManualBpm;
  final bool karaokeMode;
  final bool autoScrollOnVoice;
  final bool autoAdvance;
  final String pedalAction;
  final String displayFont;

  const AppSettings({
    this.fontSize = AppDimensions.defaultFontSize,
    this.scrollSpeedMultiplier = ScrollConstants.defaultSpeedMultiplier,
    this.voiceSensitivity = AudioConstants.voiceEnergyThreshold,
    this.manualBpmOverride = AudioConstants.defaultBpm,
    this.useManualBpm = false,
    this.karaokeMode = true,
    this.autoScrollOnVoice = true,
    this.autoAdvance = true,
    this.pedalAction = 'nextSection',
    this.displayFont = AppTextStyles.fontFamily,
  });

  AppSettings copyWith({
    double? fontSize,
    double? scrollSpeedMultiplier,
    double? voiceSensitivity,
    double? manualBpmOverride,
    bool? useManualBpm,
    bool? karaokeMode,
    bool? autoScrollOnVoice,
    bool? autoAdvance,
    String? pedalAction,
    String? displayFont,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      scrollSpeedMultiplier: scrollSpeedMultiplier ?? this.scrollSpeedMultiplier,
      voiceSensitivity: voiceSensitivity ?? this.voiceSensitivity,
      manualBpmOverride: manualBpmOverride ?? this.manualBpmOverride,
      useManualBpm: useManualBpm ?? this.useManualBpm,
      karaokeMode: karaokeMode ?? this.karaokeMode,
      autoScrollOnVoice: autoScrollOnVoice ?? this.autoScrollOnVoice,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      pedalAction: pedalAction ?? this.pedalAction,
      displayFont: displayFont ?? this.displayFont,
    );
  }
}

class SettingsService {
  static const _kFontSize = 'font_size';
  static const _kScrollSpeed = 'scroll_speed';
  static const _kVoiceSensitivity = 'voice_sensitivity';
  static const _kManualBpm = 'manual_bpm';
  static const _kUseManualBpm = 'use_manual_bpm';
  static const _kKaraokeMode = 'karaoke_mode';
  static const _kAutoScroll = 'auto_scroll_on_voice';
  static const _kAutoAdvance = 'auto_advance';
  static const _kPedalAction = 'pedal_action';
  static const _kDisplayFont = 'display_font';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      fontSize: prefs.getDouble(_kFontSize) ?? AppDimensions.defaultFontSize,
      scrollSpeedMultiplier: prefs.getDouble(_kScrollSpeed) ?? ScrollConstants.defaultSpeedMultiplier,
      voiceSensitivity: prefs.getDouble(_kVoiceSensitivity) ?? AudioConstants.voiceEnergyThreshold,
      manualBpmOverride: prefs.getDouble(_kManualBpm) ?? AudioConstants.defaultBpm,
      useManualBpm: prefs.getBool(_kUseManualBpm) ?? false,
      karaokeMode: prefs.getBool(_kKaraokeMode) ?? true,
      autoScrollOnVoice: prefs.getBool(_kAutoScroll) ?? true,
      autoAdvance: prefs.getBool(_kAutoAdvance) ?? true,
      pedalAction: prefs.getString(_kPedalAction) ?? 'nextSection',
      displayFont: prefs.getString(_kDisplayFont) ?? AppTextStyles.fontFamily,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, settings.fontSize);
    await prefs.setDouble(_kScrollSpeed, settings.scrollSpeedMultiplier);
    await prefs.setDouble(_kVoiceSensitivity, settings.voiceSensitivity);
    await prefs.setDouble(_kManualBpm, settings.manualBpmOverride);
    await prefs.setBool(_kUseManualBpm, settings.useManualBpm);
    await prefs.setBool(_kKaraokeMode, settings.karaokeMode);
    await prefs.setBool(_kAutoScroll, settings.autoScrollOnVoice);
    await prefs.setBool(_kAutoAdvance, settings.autoAdvance);
    await prefs.setString(_kPedalAction, settings.pedalAction);
    await prefs.setString(_kDisplayFont, settings.displayFont);
  }
}
