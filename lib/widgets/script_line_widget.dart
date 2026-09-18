import 'package:flutter/material.dart';
import '../models/script_line.dart';
import '../models/script_formatting.dart';
import '../models/song_theme.dart';
import '../utils/constants.dart';
import 'formatted_text.dart';
import 'section_header_widget.dart';

enum LineProximity { active, near, mid, far }

class ScriptLineWidget extends StatelessWidget {
  final ScriptLine line;
  final LineProximity proximity;
  final double fontSize;
  final bool isLoopBoundary;
  final String? displayFont;

  /// Colours, sizes and bold on parts of this line, offsets counting from
  /// the start of [ScriptLine.text].
  final List<FormatSpan> spans;
  final int? activeWordIndex;
  final bool textAlignLeft;
  final bool showHighlight;

  /// Lyric and highlight colours; the default theme when null.
  final SongTheme? theme;

  const ScriptLineWidget({
    super.key,
    required this.line,
    required this.proximity,
    required this.fontSize,
    this.isLoopBoundary = false,
    this.displayFont,
    this.spans = const [],
    this.activeWordIndex,
    this.textAlignLeft = false,
    this.showHighlight = true,
    this.theme,
  });

  SongTheme get _theme => theme ?? SongTheme.defaultTheme;

  @override
  Widget build(BuildContext context) {
    if (line.isSectionHeader) {
      return SectionHeaderWidget(
        label: line.sectionLabel ?? line.text,
        fontSize: fontSize,
        barCount: line.barCount,
        isActive: proximity == LineProximity.active,
        displayFont: displayFont,
        theme: theme,
      );
    }

    if (line.isEmpty) {
      // Wide enough to double-click, so the gap can be filled or removed
      return SizedBox(width: fontSize * 6, height: fontSize * 0.6);
    }

    return _buildLyricLine();
  }

  Widget _buildLyricLine() {
    Widget content;
    if (line.hasChords) {
      content = _buildChordLine();
    } else if (activeWordIndex != null && line.words.isNotEmpty) {
      content = _buildKaraokeText(activeWordIndex!);
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
            child: Container(width: 3, color: AppColors.loopMarker),
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

  bool get _hasFormatting => spans.isNotEmpty;

  TextAlign get _textAlign =>
      textAlignLeft ? TextAlign.left : TextAlign.center;

  Widget _buildKaraokeText(int activeIdx) {
    final base = _textStyleForProximity();
    return RichText(
      textAlign: _textAlign,
      text: TextSpan(
        children: line.words.asMap().entries.map((e) {
          final i = e.key;
          final word = e.value;
          final isActive = i == activeIdx;
          final isSung = i < activeIdx;
          final style = base.copyWith(
            color: isActive
                ? _theme.accent
                : isSung
                    ? base.color?.withValues(alpha: 0.35)
                    : base.color,
            shadows: isActive
                ? [Shadow(color: _theme.accent.withValues(alpha: 0.5), blurRadius: 12)]
                : null,
          );
          return TextSpan(
            text: i < line.words.length - 1 ? '$word ' : word,
            style: style,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStaticText() {
    return Text(
      line.text,
      textAlign: _textAlign,
      style: _textStyleForProximity(),
    );
  }

  Widget _buildFormattedText() {
    return RichText(
      textAlign: _textAlign,
      text: TextSpan(
        children: formattedSpans(line.text, spans, _textStyleForProximity()),
      ),
    );
  }

  Widget _buildChordLine() {
    final lyricStyle = _textStyleForProximity();
    final chordStyle = _chordStyle();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: line.chordSegments!.map((seg) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seg.chord ?? '',
              style: chordStyle,
            ),
            Text(
              seg.text,
              style: lyricStyle,
            ),
          ],
        );
      }).toList(),
    );
  }

  TextStyle _chordStyle() {
    final isActive = proximity == LineProximity.active;
    final chordFontSize = fontSize * 0.55;
    return TextStyle(
      fontFamily: displayFont ?? AppTextStyles.fontFamily,
      fontSize: chordFontSize,
      fontWeight: FontWeight.w700,
      color: isActive ? _theme.accent : _theme.text.withValues(alpha: 0.37),
      letterSpacing: 0.5,
      height: 1.1,
    );
  }

  TextStyle _textStyleForProximity() {
    if (!showHighlight) {
      // All lines rendered identically — no active/inactive distinction.
      return AppTextStyles.inactiveLine(fontSize, displayFont: displayFont)
          .copyWith(color: _theme.text.withValues(alpha: 0.75));
    }
    switch (proximity) {
      case LineProximity.active:
        return AppTextStyles.activeLine(fontSize, displayFont: displayFont).copyWith(
          color: _theme.text,
          shadows: [
            Shadow(
              color: _theme.text.withValues(alpha: 0.15),
              blurRadius: 20,
            ),
          ],
        );
      case LineProximity.near:
        return AppTextStyles.inactiveLine(fontSize * 0.92, displayFont: displayFont)
            .copyWith(color: _theme.nearText);
      case LineProximity.mid:
        return AppTextStyles.inactiveLine(fontSize * 0.78, displayFont: displayFont)
            .copyWith(color: _theme.nearText);
      case LineProximity.far:
        return AppTextStyles.dimmedLine(fontSize * 0.65, displayFont: displayFont)
            .copyWith(color: _theme.farText);
    }
  }
}
