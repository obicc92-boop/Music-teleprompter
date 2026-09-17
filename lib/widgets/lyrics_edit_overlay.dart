import 'dart:async';
import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/script_parser.dart';
import '../services/file_service.dart';
import '../utils/constants.dart';

class LyricsEditOverlay extends StatefulWidget {
  final Script script;
  /// Called immediately (debounced 250 ms) as the user types — drives live preview.
  final void Function(Script updated) onLiveChanged;
  /// Called once on "Apply & Save" — persists to disk and closes the panel.
  final void Function(Script updated) onSaved;
  final VoidCallback onClose;

  const LyricsEditOverlay({
    super.key,
    required this.script,
    required this.onLiveChanged,
    required this.onSaved,
    required this.onClose,
  });

  @override
  State<LyricsEditOverlay> createState() => _LyricsEditOverlayState();
}

class _LyricsEditOverlayState extends State<LyricsEditOverlay> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.script.rawText);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final newScript =
          ScriptParser.parse(_controller.text, title: widget.script.title);
      widget.onLiveChanged(newScript);
    });
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    _debounce?.cancel();
    final newText = _controller.text;
    final newScript = ScriptParser.parse(newText, title: widget.script.title);
    await FileService().saveToLibrary(newText, widget.script.title);
    if (mounted) widget.onSaved(newScript);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildEditor()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceElevated),
          left: BorderSide(color: AppColors.surfaceElevated),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'EDIT LYRICS',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              color: AppColors.activeLine,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: widget.onClose,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                color: AppColors.sectionHeader,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.surfaceElevated)),
      ),
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13,
          color: AppColors.activeLine,
          height: 1.7,
        ),
        decoration: InputDecoration(
          hintText:
              'Type lyrics here…\n\nUse [Verse 1], [Chorus] etc. for section headers.',
          hintStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            color: AppColors.dimmedLine,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceElevated),
          left: BorderSide(color: AppColors.surfaceElevated),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            _saving ? 'Saving…' : 'Apply & Save',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
