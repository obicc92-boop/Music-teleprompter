import 'package:flutter/material.dart';
import '../models/song_theme.dart';
import '../utils/constants.dart';

class SectionHeaderWidget extends StatelessWidget {
  final String label;
  final int? barCount;
  final double fontSize;
  final bool isActive;
  final String? displayFont;
  final SongTheme? theme;

  const SectionHeaderWidget({
    super.key,
    required this.label,
    required this.fontSize,
    this.barCount,
    this.isActive = false,
    this.displayFont,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = this.theme ?? SongTheme.defaultTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.sectionSpacing * 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dividerLine(theme),
          const SizedBox(width: 16),
          Text(
            barCount != null ? '$label  ·  $barCount BARS' : label,
            style: AppTextStyles.sectionHeader(fontSize, displayFont: displayFont).copyWith(
              color: isActive ? theme.accent : theme.sectionText,
            ),
          ),
          const SizedBox(width: 16),
          _dividerLine(theme),
        ],
      ),
    );
  }

  Widget _dividerLine(SongTheme theme) {
    return Container(
      width: 40,
      height: 1,
      color: theme.text.withValues(alpha: 0.21),
    );
  }
}
