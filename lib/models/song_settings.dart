import '../services/settings_service.dart';

/// A song's own speed and display settings.
/// A null field means the song follows the default from [AppSettings].
class SongSettings {
  final double? scrollSpeedMultiplier;
  final double? fontSize;
  final String? displayFont;
  final bool? textAlignLeft;
  final bool? showActiveLineHighlight;
  final double? activeLineYOffset;
  final String? colorTheme;

  const SongSettings({
    this.scrollSpeedMultiplier,
    this.fontSize,
    this.displayFont,
    this.textAlignLeft,
    this.showActiveLineHighlight,
    this.activeLineYOffset,
    this.colorTheme,
  });

  static const none = SongSettings();

  bool get isEmpty =>
      scrollSpeedMultiplier == null &&
      fontSize == null &&
      displayFont == null &&
      textAlignLeft == null &&
      showActiveLineHighlight == null &&
      activeLineYOffset == null &&
      colorTheme == null;

  /// The settings this song plays with: its own values over the defaults.
  AppSettings applyTo(AppSettings defaults) => defaults.copyWith(
        scrollSpeedMultiplier: scrollSpeedMultiplier,
        fontSize: fontSize,
        displayFont: displayFont,
        textAlignLeft: textAlignLeft,
        showActiveLineHighlight: showActiveLineHighlight,
        activeLineYOffset: activeLineYOffset,
        colorTheme: colorTheme,
      );

  /// Keeps every setting that differs between [before] and [after] as this
  /// song's own value; untouched settings stay as they were.
  SongSettings withChanges(AppSettings before, AppSettings after) =>
      SongSettings(
        scrollSpeedMultiplier:
            after.scrollSpeedMultiplier != before.scrollSpeedMultiplier
                ? after.scrollSpeedMultiplier
                : scrollSpeedMultiplier,
        fontSize:
            after.fontSize != before.fontSize ? after.fontSize : fontSize,
        displayFont: after.displayFont != before.displayFont
            ? after.displayFont
            : displayFont,
        textAlignLeft: after.textAlignLeft != before.textAlignLeft
            ? after.textAlignLeft
            : textAlignLeft,
        showActiveLineHighlight:
            after.showActiveLineHighlight != before.showActiveLineHighlight
                ? after.showActiveLineHighlight
                : showActiveLineHighlight,
        activeLineYOffset: after.activeLineYOffset != before.activeLineYOffset
            ? after.activeLineYOffset
            : activeLineYOffset,
        colorTheme: after.colorTheme != before.colorTheme
            ? after.colorTheme
            : colorTheme,
      );

  /// Sets this song's speed, or clears it with null so the default is used.
  SongSettings withSpeed(double? speed) => SongSettings(
        scrollSpeedMultiplier: speed,
        fontSize: fontSize,
        displayFont: displayFont,
        textAlignLeft: textAlignLeft,
        showActiveLineHighlight: showActiveLineHighlight,
        activeLineYOffset: activeLineYOffset,
        colorTheme: colorTheme,
      );

  /// Sets this song's colours, or clears them with null so the default is used.
  SongSettings withColorTheme(String? code) => SongSettings(
        scrollSpeedMultiplier: scrollSpeedMultiplier,
        fontSize: fontSize,
        displayFont: displayFont,
        textAlignLeft: textAlignLeft,
        showActiveLineHighlight: showActiveLineHighlight,
        activeLineYOffset: activeLineYOffset,
        colorTheme: code,
      );

  Map<String, dynamic> toJson() => {
        if (scrollSpeedMultiplier != null)
          'scrollSpeedMultiplier': scrollSpeedMultiplier,
        if (fontSize != null) 'fontSize': fontSize,
        if (displayFont != null) 'displayFont': displayFont,
        if (textAlignLeft != null) 'textAlignLeft': textAlignLeft,
        if (showActiveLineHighlight != null)
          'showActiveLineHighlight': showActiveLineHighlight,
        if (activeLineYOffset != null) 'activeLineYOffset': activeLineYOffset,
        if (colorTheme != null) 'colorTheme': colorTheme,
      };

  factory SongSettings.fromJson(Map<String, dynamic> j) => SongSettings(
        scrollSpeedMultiplier: (j['scrollSpeedMultiplier'] as num?)?.toDouble(),
        fontSize: (j['fontSize'] as num?)?.toDouble(),
        displayFont: j['displayFont'] as String?,
        textAlignLeft: j['textAlignLeft'] as bool?,
        showActiveLineHighlight: j['showActiveLineHighlight'] as bool?,
        activeLineYOffset: (j['activeLineYOffset'] as num?)?.toDouble(),
        colorTheme: j['colorTheme'] as String?,
      );
}
