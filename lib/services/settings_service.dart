import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_theme.dart';
import '../utils/constants.dart';

class AppSettings {
  final double fontSize;
  final double scrollSpeedMultiplier;
  final bool autoAdvance;

  /// A 3-2-1 count before a song starts from the top.
  final bool countdown;
  final String pedalAction;
  final String displayFont;
  final bool textAlignLeft;
  final double activeLineYOffset;
  final bool showActiveLineHighlight;

  /// The lyrics screen's colours, as saved by [SongTheme.code].
  final String colorTheme;

  const AppSettings({
    this.fontSize = AppDimensions.defaultFontSize,
    this.scrollSpeedMultiplier = ScrollConstants.defaultSpeedMultiplier,
    this.autoAdvance = true,
    this.countdown = true,
    this.pedalAction = 'nextSection',
    this.displayFont = AppTextStyles.fontFamily,
    this.textAlignLeft = false,
    this.activeLineYOffset = AppDimensions.activeLineYOffset,
    this.showActiveLineHighlight = true,
    this.colorTheme = 'default',
  });

  SongTheme get songTheme => SongTheme.fromCode(colorTheme);

  AppSettings copyWith({
    double? fontSize,
    double? scrollSpeedMultiplier,
    bool? autoAdvance,
    bool? countdown,
    String? pedalAction,
    String? displayFont,
    bool? textAlignLeft,
    double? activeLineYOffset,
    bool? showActiveLineHighlight,
    String? colorTheme,
  }) =>
      AppSettings(
        fontSize: fontSize ?? this.fontSize,
        scrollSpeedMultiplier:
            scrollSpeedMultiplier ?? this.scrollSpeedMultiplier,
        autoAdvance: autoAdvance ?? this.autoAdvance,
        countdown: countdown ?? this.countdown,
        pedalAction: pedalAction ?? this.pedalAction,
        displayFont: displayFont ?? this.displayFont,
        textAlignLeft: textAlignLeft ?? this.textAlignLeft,
        activeLineYOffset: activeLineYOffset ?? this.activeLineYOffset,
        showActiveLineHighlight:
            showActiveLineHighlight ?? this.showActiveLineHighlight,
        colorTheme: colorTheme ?? this.colorTheme,
      );
}

class SettingsService {
  static const _kFontSize = 'font_size';
  static const _kScrollSpeed = 'scroll_speed';
  static const _kAutoAdvance = 'auto_advance';
  static const _kCountdown = 'countdown';
  static const _kPedalAction = 'pedal_action';
  static const _kDisplayFont = 'display_font';
  static const _kTextAlignLeft = 'text_align_left';
  static const _kActiveLineYOffset = 'active_line_y_offset';
  static const _kShowHighlight = 'show_active_line_highlight';
  static const _kColorTheme = 'color_theme';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      fontSize: prefs.getDouble(_kFontSize) ?? AppDimensions.defaultFontSize,
      scrollSpeedMultiplier: prefs.getDouble(_kScrollSpeed) ??
          ScrollConstants.defaultSpeedMultiplier,
      autoAdvance: prefs.getBool(_kAutoAdvance) ?? true,
      countdown: prefs.getBool(_kCountdown) ?? true,
      pedalAction: prefs.getString(_kPedalAction) ?? 'nextSection',
      displayFont: prefs.getString(_kDisplayFont) ?? AppTextStyles.fontFamily,
      textAlignLeft: prefs.getBool(_kTextAlignLeft) ?? false,
      activeLineYOffset: prefs.getDouble(_kActiveLineYOffset) ??
          AppDimensions.activeLineYOffset,
      showActiveLineHighlight: prefs.getBool(_kShowHighlight) ?? true,
      colorTheme: prefs.getString(_kColorTheme) ?? 'default',
    );
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, s.fontSize);
    await prefs.setDouble(_kScrollSpeed, s.scrollSpeedMultiplier);
    await prefs.setBool(_kAutoAdvance, s.autoAdvance);
    await prefs.setBool(_kCountdown, s.countdown);
    await prefs.setString(_kPedalAction, s.pedalAction);
    await prefs.setString(_kDisplayFont, s.displayFont);
    await prefs.setBool(_kTextAlignLeft, s.textAlignLeft);
    await prefs.setDouble(_kActiveLineYOffset, s.activeLineYOffset);
    await prefs.setBool(_kShowHighlight, s.showActiveLineHighlight);
    await prefs.setString(_kColorTheme, s.colorTheme);
  }
}
