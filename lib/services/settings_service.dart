import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AppSettings {
  final double fontSize;
  final double scrollSpeedMultiplier;
  final bool autoAdvance;
  final String pedalAction;
  final String displayFont;
  final bool textAlignLeft;
  final double activeLineYOffset;
  final bool showActiveLineHighlight;

  const AppSettings({
    this.fontSize = AppDimensions.defaultFontSize,
    this.scrollSpeedMultiplier = ScrollConstants.defaultSpeedMultiplier,
    this.autoAdvance = true,
    this.pedalAction = 'nextSection',
    this.displayFont = AppTextStyles.fontFamily,
    this.textAlignLeft = false,
    this.activeLineYOffset = AppDimensions.activeLineYOffset,
    this.showActiveLineHighlight = true,
  });

  AppSettings copyWith({
    double? fontSize,
    double? scrollSpeedMultiplier,
    bool? autoAdvance,
    String? pedalAction,
    String? displayFont,
    bool? textAlignLeft,
    double? activeLineYOffset,
    bool? showActiveLineHighlight,
  }) =>
      AppSettings(
        fontSize: fontSize ?? this.fontSize,
        scrollSpeedMultiplier:
            scrollSpeedMultiplier ?? this.scrollSpeedMultiplier,
        autoAdvance: autoAdvance ?? this.autoAdvance,
        pedalAction: pedalAction ?? this.pedalAction,
        displayFont: displayFont ?? this.displayFont,
        textAlignLeft: textAlignLeft ?? this.textAlignLeft,
        activeLineYOffset: activeLineYOffset ?? this.activeLineYOffset,
        showActiveLineHighlight:
            showActiveLineHighlight ?? this.showActiveLineHighlight,
      );
}

class SettingsService {
  static const _kFontSize = 'font_size';
  static const _kScrollSpeed = 'scroll_speed';
  static const _kAutoAdvance = 'auto_advance';
  static const _kPedalAction = 'pedal_action';
  static const _kDisplayFont = 'display_font';
  static const _kTextAlignLeft = 'text_align_left';
  static const _kActiveLineYOffset = 'active_line_y_offset';
  static const _kShowHighlight = 'show_active_line_highlight';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      fontSize: prefs.getDouble(_kFontSize) ?? AppDimensions.defaultFontSize,
      scrollSpeedMultiplier: prefs.getDouble(_kScrollSpeed) ??
          ScrollConstants.defaultSpeedMultiplier,
      autoAdvance: prefs.getBool(_kAutoAdvance) ?? true,
      pedalAction: prefs.getString(_kPedalAction) ?? 'nextSection',
      displayFont: prefs.getString(_kDisplayFont) ?? AppTextStyles.fontFamily,
      textAlignLeft: prefs.getBool(_kTextAlignLeft) ?? false,
      activeLineYOffset: prefs.getDouble(_kActiveLineYOffset) ??
          AppDimensions.activeLineYOffset,
      showActiveLineHighlight: prefs.getBool(_kShowHighlight) ?? true,
    );
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, s.fontSize);
    await prefs.setDouble(_kScrollSpeed, s.scrollSpeedMultiplier);
    await prefs.setBool(_kAutoAdvance, s.autoAdvance);
    await prefs.setString(_kPedalAction, s.pedalAction);
    await prefs.setString(_kDisplayFont, s.displayFont);
    await prefs.setBool(_kTextAlignLeft, s.textAlignLeft);
    await prefs.setDouble(_kActiveLineYOffset, s.activeLineYOffset);
    await prefs.setBool(_kShowHighlight, s.showActiveLineHighlight);
  }
}
