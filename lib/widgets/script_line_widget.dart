import 'package:flutter/material.dart';
import '../models/script_line.dart';
import '../utils/constants.dart';
import 'section_header_widget.dart';

enum LineProximity { active, near, mid, far }

class ScriptLineWidget extends StatelessWidget {
  final ScriptLine line;
  final LineProximity proximity;
  final double fontSize;
  final bool karaokeEnabled;
  final int highlightedWordIndex;
  final bool isLoopBoundary;
  final String? displayFont;

  const ScriptLineWidget({
    super.key,
    required this.line,
    required this.proximity,
    required this.fontSize,
    this.karaokeEnabled = false,
    this.highlightedWordIndex = -1,
    this.isLoopBoundary = false,
    this.displayFont,
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

  Widget _buildStaticText() {
    return Text(
      line.text,
      textAlign: TextAlign.center,
      style: _textStyleForProximity(),
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
          final isPast = karaokeEnabled && i < highlightedWordIndex;
          final isCurrent = karaokeEnabled && i == highlightedWordIndex;

          TextStyle style;
          if (isPast) {
            style = AppTextStyles.karaokePast(fontSize, displayFont: displayFont);
          } else if (isCurrent) {
            style = AppTextStyles.activeLine(fontSize, displayFont: displayFont).copyWith(
              color: AppColors.highlightKaraoke,
              shadows: [
                Shadow(
                  color: AppColors.highlightKaraoke.withValues(alpha: 0.6),
                  blurRadius: 12,
                ),
              ],
            );
          } else {
            style = AppTextStyles.activeLine(fontSize, displayFont: displayFont);
          }

          return TextSpan(
            text: i < line.words.length - 1 ? '$word ' : word,
            style: style,
          );
        }).toList(),
      ),
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
