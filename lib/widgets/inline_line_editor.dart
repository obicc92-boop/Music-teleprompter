import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/script_formatting.dart';
import '../utils/app_platform.dart';
import '../utils/constants.dart';
import 'formatted_text_controller.dart';
import 'lyrics_format_toolbar.dart';

/// One lyric line edited where it stands on the stage screen, in its stage
/// font and colours, with the formatting tools underneath. Enter, or a tap
/// anywhere else, keeps the edit; Esc cancels; Shift+Enter starts a new
/// line.
class InlineLineEditor extends StatefulWidget {
  final String text;

  /// Formatting on this line, offsets counting from the start of [text].
  final List<FormatSpan> spans;
  final TextStyle style;
  final TextAlign textAlign;
  final Color accent;
  final Color textColor;

  /// The new text and its formatting (offsets from the start of the text).
  final void Function(String text, ScriptFormatting formatting) onSave;
  final VoidCallback onCancel;

  /// Backspace or Delete on an empty box: take the line out altogether.
  final VoidCallback? onDelete;

  const InlineLineEditor({
    super.key,
    required this.text,
    required this.spans,
    required this.style,
    required this.textAlign,
    required this.accent,
    required this.textColor,
    required this.onSave,
    required this.onCancel,
    this.onDelete,
  });

  @override
  State<InlineLineEditor> createState() => _InlineLineEditorState();
}

class _InlineLineEditorState extends State<InlineLineEditor> {
  late final FormattedTextController _controller = FormattedTextController(
    text: widget.text,
    formatting: ScriptFormatting(spans: widget.spans),
  );
  final _focus = FocusNode(debugLabel: 'InlineLineEditor');
  final _tapGroup = Object();

  @override
  void initState() {
    super.initState();
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() => widget.onSave(_controller.text, _controller.formatting);

  // Tapping away keeps what was typed, like leaving any other field; an
  // untouched line is simply closed. Not for taps in a dialog opened from
  // the toolbar, such as the colour picker.
  void _onTapOutside(PointerDownEvent _) {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final changed = _controller.text != widget.text ||
        !_controller.formatting.sameAs(ScriptFormatting(spans: widget.spans));
    if (changed) {
      _save();
    } else {
      widget.onCancel();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _save();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.backspace ||
            key == LogicalKeyboardKey.delete) &&
        _controller.text.isEmpty &&
        widget.onDelete != null) {
      widget.onDelete!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final touch = AppPlatform.isTouch;
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.textColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.accent.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              groupId: _tapGroup,
              onTapOutside: _onTapOutside,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlign: widget.textAlign,
              style: widget.style,
              cursorColor: widget.accent,
              decoration: InputDecoration.collapsed(
                hintText: widget.onDelete == null
                    ? ''
                    : 'Type a line here — or press Delete to close the gap',
                hintStyle: widget.style.copyWith(
                  fontSize: (widget.style.fontSize ?? 40) * 0.32,
                  fontWeight: FontWeight.w400,
                  color: widget.textColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: widget.textAlign == TextAlign.left
                ? Alignment.centerLeft
                : Alignment.center,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Color(0x80000000), blurRadius: 24),
                ],
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  LyricsFormatToolbar(
                    controller: _controller,
                    tapGroup: _tapGroup,
                    showHint: false,
                  ),
                  // Buttons for the mouse and for phones, where Enter makes
                  // a new line instead
                  TapRegion(
                    groupId: _tapGroup,
                    child: ExcludeFocus(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: widget.onCancel,
                            child: Text(touch ? 'Cancel' : 'Cancel (Esc)'),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: _save,
                            child: Text(touch ? 'Done' : 'Done (Enter)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
