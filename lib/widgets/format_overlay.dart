import 'package:flutter/material.dart';
import '../models/script.dart';
import '../models/script_line.dart';
import '../models/script_formatting.dart';
import '../utils/constants.dart';

class FormatOverlay extends StatefulWidget {
  final Script script;
  final ScriptFormatting formatting;
  final void Function(ScriptFormatting) onChanged;
  final VoidCallback onClose;

  const FormatOverlay({
    super.key,
    required this.script,
    required this.formatting,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<FormatOverlay> createState() => _FormatOverlayState();
}

class _FormatOverlayState extends State<FormatOverlay> {
  late ScriptFormatting _formatting;
  int? _selectedLine;
  int? _selectedWord;

  static const _colorOptions = <(int?, String)>[
    (null, 'Default'),
    (0xFFFF6B35, 'Orange'),
    (0xFFEF5350, 'Red'),
    (0xFF4CAF50, 'Green'),
    (0xFF4FC3F7, 'Cyan'),
    (0xFFFFD700, 'Gold'),
    (0xFFCE93D8, 'Purple'),
  ];

  @override
  void initState() {
    super.initState();
    _formatting = widget.formatting;
  }

  WordFormat? get _selectedFormat =>
      _selectedLine != null && _selectedWord != null
          ? _formatting.formatFor(_selectedLine!, _selectedWord!)
          : null;

  void _selectWord(int lineIndex, int wordIndex) {
    setState(() {
      if (_selectedLine == lineIndex && _selectedWord == wordIndex) {
        _selectedLine = null;
        _selectedWord = null;
      } else {
        _selectedLine = lineIndex;
        _selectedWord = wordIndex;
      }
    });
  }

  WordFormat _buildFormat({
    int? colorValue,
    bool clearColor = false,
    double? fontSizeScale,
    bool? bold,
  }) {
    final existing = _selectedFormat;
    return WordFormat(
      lineIndex: _selectedLine!,
      wordIndex: _selectedWord!,
      colorValue: clearColor ? null : (colorValue ?? existing?.colorValue),
      fontSizeScale: fontSizeScale ?? existing?.fontSizeScale ?? 1.0,
      bold: bold ?? existing?.bold ?? false,
    );
  }

  void _applyFormat(WordFormat fmt) {
    final updated = _formatting.withUpdate(fmt);
    setState(() => _formatting = updated);
    widget.onChanged(updated);
  }

  void _clearSelected() {
    if (_selectedLine == null || _selectedWord == null) return;
    final updated = _formatting.clearWord(_selectedLine!, _selectedWord!);
    setState(() => _formatting = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.96),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildScriptList()),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceElevated)),
      ),
      child: Row(
        children: [
          const Text(
            'FORMAT LYRICS',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: AppColors.activeLine,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onClose,
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptList() {
    final lines = widget.script.allLines;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      itemCount: lines.length,
      itemBuilder: (ctx, i) => _buildLine(i, lines[i]),
    );
  }

  Widget _buildLine(int lineIndex, ScriptLine line) {
    if (line.isSectionHeader) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          line.sectionLabel ?? line.text,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 10,
            color: AppColors.sectionHeader,
            letterSpacing: 2,
          ),
        ),
      );
    }

    if (line.isEmpty) return const SizedBox(height: 6);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: line.words.asMap().entries.map((entry) {
          final wordIndex = entry.key;
          final word = entry.value;
          final fmt = _formatting.formatFor(lineIndex, wordIndex);
          final isSelected =
              _selectedLine == lineIndex && _selectedWord == wordIndex;

          return GestureDetector(
            onTap: () => _selectWord(lineIndex, wordIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : (fmt != null
                        ? AppColors.surfaceElevated
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : (fmt != null
                          ? AppColors.sectionHeader.withValues(alpha: 0.35)
                          : Colors.transparent),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (fmt?.colorValue != null)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Color(fmt!.colorValue!),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    word,
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 15,
                      fontWeight: fmt?.bold == true
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: fmt?.colorValue != null
                          ? Color(fmt!.colorValue!)
                          : (isSelected
                              ? AppColors.accent
                              : AppColors.inactiveLine),
                    ),
                  ),
                  if (fmt != null && fmt.fontSizeScale > 1.0)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        'A+',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 7,
                          color: AppColors.sectionHeader,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToolbar() {
    final hasSelection = _selectedLine != null && _selectedWord != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceElevated)),
      ),
      child: hasSelection
          ? _buildActiveToolbar()
          : const SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  'Tap any word to format it',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 13,
                    color: AppColors.sectionHeader,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildActiveToolbar() {
    final fmt = _selectedFormat;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color row
        Row(
          children: [
            const SizedBox(
              width: 48,
              child: Text(
                'Color',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 11,
                  color: AppColors.sectionHeader,
                ),
              ),
            ),
            ..._colorOptions.map((option) {
              final (colorValue, label) = option;
              final isSelected = fmt?.colorValue == colorValue;
              final displayColor =
                  colorValue != null ? Color(colorValue) : AppColors.activeLine;

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Tooltip(
                  message: label,
                  child: GestureDetector(
                    onTap: () => _applyFormat(_buildFormat(
                      colorValue: colorValue,
                      clearColor: colorValue == null,
                    )),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: AppColors.accent, width: 2.5)
                            : Border.all(
                                color: Colors.white12, width: 1.0),
                      ),
                      child: colorValue == null
                          ? const Icon(Icons.close,
                              size: 13, color: AppColors.background)
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        // Size + Bold + Clear row
        Row(
          children: [
            const SizedBox(
              width: 48,
              child: Text(
                'Style',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 11,
                  color: AppColors.sectionHeader,
                ),
              ),
            ),
            _sizeChip('Aa', 1.0, fmt?.fontSizeScale ?? 1.0),
            const SizedBox(width: 8),
            _sizeChip('Aa+', 1.35, fmt?.fontSizeScale ?? 1.0),
            const SizedBox(width: 8),
            _boldChip(fmt?.bold ?? false),
            const Spacer(),
            _clearButton(),
          ],
        ),
      ],
    );
  }

  Widget _sizeChip(String label, double size, double currentSize) {
    final isSelected = (currentSize - size).abs() < 0.01;
    return GestureDetector(
      onTap: () => _applyFormat(_buildFormat(fontSizeScale: size)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            color: isSelected ? AppColors.accent : AppColors.inactiveLine,
          ),
        ),
      ),
    );
  }

  Widget _boldChip(bool isBold) {
    return GestureDetector(
      onTap: () => _applyFormat(_buildFormat(bold: !isBold)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isBold
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isBold ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          'B',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isBold ? AppColors.accent : AppColors.inactiveLine,
          ),
        ),
      ),
    );
  }

  Widget _clearButton() {
    return GestureDetector(
      onTap: _clearSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: const Color(0xFFEF5350).withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Clear',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            color: Color(0xFFEF5350),
          ),
        ),
      ),
    );
  }
}
