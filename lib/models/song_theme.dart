import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Colours of the lyrics screen: the background, and a highlight colour for
/// section names, chords and the word being sung. Lyrics are light on dark
/// backgrounds and dark on light ones, so any background stays usable.
class SongTheme {
  final String id;
  final String label;
  final Color background;
  final Color accent;

  const SongTheme({
    required this.id,
    required this.label,
    required this.background,
    required this.accent,
  });

  static const customId = 'custom';

  /// Colours the user picked themselves.
  factory SongTheme.custom({
    required Color background,
    required Color accent,
  }) => SongTheme(
    id: customId,
    label: 'Custom',
    background: background.withAlpha(255),
    accent: accent.withAlpha(255),
  );

  bool get isCustom => id == customId;

  static const List<SongTheme> presets = [
    SongTheme(
      id: 'default',
      label: 'Classic',
      background: Color(0xFF0A0A0A),
      accent: Color(0xFFFF6B35),
    ),
    SongTheme(
      id: 'black',
      label: 'Pure black',
      background: Color(0xFF000000),
      accent: Color(0xFFFF6B35),
    ),
    SongTheme(
      id: 'red',
      label: 'Night red',
      background: Color(0xFF1A0000),
      accent: Color(0xFFFF3333),
    ),
    SongTheme(
      id: 'amber',
      label: 'Amber',
      background: Color(0xFF0D0800),
      accent: Color(0xFFFFB300),
    ),
    SongTheme(
      id: 'green',
      label: 'Stage',
      background: Color(0xFF001A00),
      accent: Color(0xFF69FF47),
    ),
    SongTheme(
      id: 'ocean',
      label: 'Ocean',
      background: Color(0xFF00101A),
      accent: Color(0xFF00BCD4),
    ),
    SongTheme(
      id: 'purple',
      label: 'Purple',
      background: Color(0xFF0D0010),
      accent: Color(0xFFCE93D8),
    ),
  ];

  static SongTheme get defaultTheme => presets.first;

  /// How a theme is saved: a preset id, or "custom:RRGGBB:RRGGBB".
  String get code =>
      isCustom ? '$customId:${hex(background)}:${hex(accent)}' : id;

  static SongTheme fromCode(String? code) {
    if (code == null) return defaultTheme;
    if (code.startsWith('$customId:')) {
      final parts = code.split(':');
      final background = parts.length == 3 ? parseHex(parts[1]) : null;
      final accent = parts.length == 3 ? parseHex(parts[2]) : null;
      if (background == null || accent == null) return defaultTheme;
      return SongTheme.custom(background: background, accent: accent);
    }
    return presets.firstWhere((t) => t.id == code, orElse: () => defaultTheme);
  }

  @override
  bool operator ==(Object other) => other is SongTheme && other.code == code;

  @override
  int get hashCode => code.hashCode;

  // ── Lyric colours ─────────────────────────────────────────────────────────

  static const _lightText = Color(0xFFFFFFFF);
  static const _darkText = Color(0xFF111111);

  /// The current line.
  Color get text =>
      contrast(_lightText, background) >= contrast(_darkText, background)
      ? _lightText
      : _darkText;

  /// The lines just before and after the current one.
  Color get nearText => text.withValues(alpha: 0.33);

  /// Lines further away.
  Color get farText => text.withValues(alpha: 0.2);

  /// Section names that aren't current, and their divider lines.
  Color get sectionText => text.withValues(alpha: 0.53);

  // ── Readability ───────────────────────────────────────────────────────────

  /// What would make lyrics hard to read with these colours; empty when
  /// they read well.
  List<String> get readabilityWarnings => [
    if (contrast(text, background) < 7)
      'Lyrics will be hard to read on this background. Very dark or very light colours read best.'
    else if (background.computeLuminance() > 0.3)
      'A bright background lights up your face and can dazzle you on a dark stage.',
    if (contrast(accent, background) < 3)
      'The highlight colour hardly stands out from the background.',
  ];

  /// WCAG contrast ratio, from 1 (same colour) to 21 (black on white).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  static String hex(Color c) =>
      (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  static Color? parseHex(String input) {
    final value = input.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value, radix: 16));
  }
}
