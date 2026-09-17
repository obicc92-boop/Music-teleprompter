import 'package:flutter/material.dart';

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

  static const List<SongTheme> presets = [
    SongTheme(id: 'default',  label: 'Default',  background: Color(0xFF0A0A0A), accent: Color(0xFFFF6B35)),
    SongTheme(id: 'red',      label: 'Night Red', background: Color(0xFF1A0000), accent: Color(0xFFFF3333)),
    SongTheme(id: 'amber',    label: 'Amber',     background: Color(0xFF0D0800), accent: Color(0xFFFFB300)),
    SongTheme(id: 'green',    label: 'Stage',     background: Color(0xFF001A00), accent: Color(0xFF69FF47)),
    SongTheme(id: 'ocean',    label: 'Ocean',     background: Color(0xFF00101A), accent: Color(0xFF00BCD4)),
    SongTheme(id: 'purple',   label: 'Purple',    background: Color(0xFF0D0010), accent: Color(0xFFCE93D8)),
  ];

  static SongTheme get defaultTheme => presets.first;

  static SongTheme fromId(String id) =>
      presets.firstWhere((t) => t.id == id, orElse: () => defaultTheme);
}
