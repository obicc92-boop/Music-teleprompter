import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'word_recognition_service.dart';

// Sentinel that distinguishes "caller passed null" from "caller passed nothing"
const _absent = Object();

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
  final WordSyncMode wordSyncMode;
  final String whisperModelPath;
  final String? audioDeviceId;

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
    this.wordSyncMode = WordSyncMode.off,
    this.whisperModelPath = '',
    this.audioDeviceId,
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
    WordSyncMode? wordSyncMode,
    String? whisperModelPath,
    Object? audioDeviceId = _absent,
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
      wordSyncMode: wordSyncMode ?? this.wordSyncMode,
      whisperModelPath: whisperModelPath ?? this.whisperModelPath,
      audioDeviceId: identical(audioDeviceId, _absent)
          ? this.audioDeviceId
          : audioDeviceId as String?,
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
  static const _kWordSyncMode = 'word_sync_mode';
  static const _kWhisperModelPath = 'whisper_model_path';
  static const _kAudioDeviceId = 'audio_device_id';

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
      wordSyncMode: WordSyncMode.values.firstWhere(
        (m) => m.name == prefs.getString(_kWordSyncMode),
        orElse: () => WordSyncMode.off,
      ),
      whisperModelPath: prefs.getString(_kWhisperModelPath) ?? '',
      audioDeviceId: prefs.getString(_kAudioDeviceId),
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
    await prefs.setString(_kWordSyncMode, settings.wordSyncMode.name);
    await prefs.setString(_kWhisperModelPath, settings.whisperModelPath);
    if (settings.audioDeviceId != null) {
      await prefs.setString(_kAudioDeviceId, settings.audioDeviceId!);
    } else {
      await prefs.remove(_kAudioDeviceId);
    }
  }
}
