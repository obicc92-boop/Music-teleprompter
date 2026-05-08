import 'package:flutter/material.dart';
import '../models/script_line.dart';
import '../models/script_formatting.dart';
import '../utils/constants.dart';
import 'section_header_widget.dart';

enum LineProximity { active, near, mid, far }

class ScriptLineWidget extends StatelessWidget {
  final ScriptLine line;
  final int lineIndex;
  final LineProximity proximity;
  final double fontSize;
  final bool karaokeEnabled;
  final int highlightedWordIndex;
  final bool isLoopBoundary;
  final String? displayFont;
  final ScriptFormatting? formatting;

  const ScriptLineWidget({
    super.key,
    required this.line,
    required this.lineIndex,
    required this.proximity,
    required this.fontSize,
    this.karaokeEnabled = false,
    this.highlightedWordIndex = -1,
    this.isLoopBoundary = false,
    this.displayFont,
    this.formatting,
  });

  @override
  Widget build(BuildContext context) {
    if (line.isSectionHeader) {
      return SectionHeaderWidget(
        label: line.sectionLabel ?? line.text,
        fontSize: fontSize,
        barCount: line.barCount,
        isActive: proximity == LineProximity.active,
        displayFont: displayFont,
      );
    }

    if (line.isEmpty) {
      return SizedBox(height: fontSize * 0.6);
    }

    return _buildLyricLine();
  }

  Widget _buildLyricLine() {
    Widget content;

    if (karaokeEnabled && proximity == LineProximity.active && line.words.isNotEmpty) {
      content = _buildKaraokeText();
    } else if (_hasFormatting && line.words.isNotEmpty) {
      content = _buildFormattedText();
    } else {
      content = _buildStaticText();
    }

    if (isLoopBoundary) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              color: AppColors.loopMarker,
            ),
          ),
        ],
      );
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: _textStyleForProximity(),
      child: content,
    );
  }

  bool get _hasFormatting =>
      formatting != null && formatting!.hasFormatsForLine(lineIndex);

  Widget _buildStaticText() {
    return Text(
      line.text,
      textAlign: TextAlign.center,
      style: _textStyleForProximity(),
    );
  }

  Widget _buildFormattedText() {
    final baseStyle = _textStyleForProximity();
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: line.words.asMap().entries.map((entry) {
          final i = entry.key;
          final word = entry.value;
          final fmt = formatting?.formatFor(lineIndex, i);
          final style = _applyWordFormat(baseStyle, fmt);
          return TextSpan(
            text: i < line.words.length - 1 ? '$word ' : word,
            style: style,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKaraokeText() {
    if (line.words.isEmpty) return _buildStaticText();

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: line.words.asMap().entries.map((entry) {
          final i = entry.key;
          final word = entry.value;
          final fmt = formatting?.formatFor(lineIndex, i);
          final isPast = karaokeEnabled && i < highlightedWordIndex;
          final isCurrent = karaokeEnabled && i == highlightedWordIndex;
          final scaledSize = fontSize * (fmt?.fontSizeScale ?? 1.0);
          final weight = fmt?.bold == true ? FontWeight.w900 : FontWeight.w700;

          TextStyle style;
          if (isPast) {
            style = AppTextStyles.karaokePast(scaledSize, displayFont: displayFont)
                .copyWith(fontWeight: weight);
          } else if (isCurrent) {
            style = AppTextStyles.activeLine(scaledSize, displayFont: displayFont).copyWith(
              fontWeight: weight,
              color: AppColors.highlightKaraoke,
              shadows: [
                Shadow(
                  color: AppColors.highlightKaraoke.withValues(alpha: 0.6),
                  blurRadius: 12,
                ),
              ],
            );
          } else {
            style = AppTextStyles.activeLine(scaledSize, displayFont: displayFont).copyWith(
              fontWeight: weight,
              color: fmt?.colorValue != null ? Color(fmt!.colorValue!) : null,
            );
          }

          return TextSpan(
            text: i < line.words.length - 1 ? '$word ' : word,
            style: style,
          );
        }).toList(),
      ),
    );
  }

  TextStyle _applyWordFormat(TextStyle base, WordFormat? fmt) {
    if (fmt == null) return base;
    return base.copyWith(
      color: fmt.colorValue != null ? Color(fmt.colorValue!) : base.color,
      fontSize: (base.fontSize ?? fontSize) * fmt.fontSizeScale,
      fontWeight: fmt.bold ? FontWeight.w900 : base.fontWeight,
    );
  }

  TextStyle _textStyleForProximity() {
    switch (proximity) {
      case LineProximity.active:
        return AppTextStyles.activeLine(fontSize, displayFont: displayFont).copyWith(
          shadows: [
            Shadow(
              color: AppColors.activeLine.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          ],
        );
      case LineProximity.near:
        return AppTextStyles.inactiveLine(fontSize * 0.92, displayFont: displayFont);
      case LineProximity.mid:
        return AppTextStyles.inactiveLine(fontSize * 0.78, displayFont: displayFont);
      case LineProximity.far:
        return AppTextStyles.dimmedLine(fontSize * 0.65, displayFont: displayFont);
    }
  }
}
