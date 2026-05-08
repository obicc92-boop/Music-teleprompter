import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/script_parser.dart';
import '../services/file_service.dart';
import '../utils/constants.dart';

class LyricsEditOverlay extends StatefulWidget {
  final Script script;
  final void Function(Script updated) onSaved;
  final VoidCallback onClose;

  const LyricsEditOverlay({
    super.key,
    required this.script,
    required this.onSaved,
    required this.onClose,
  });

  @override
  State<LyricsEditOverlay> createState() => _LyricsEditOverlayState();
}

class _LyricsEditOverlayState extends State<LyricsEditOverlay> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.script.rawText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    final newText = _controller.text;
    final newScript = ScriptParser.parse(newText, title: widget.script.title);
    await FileService().saveToLibrary(newText, widget.script.title);
    if (mounted) {
      widget.onSaved(newScript);
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: 0.96),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceElevated)),
      ),
      child: Row(
        children: [
          const Text(
            'EDIT LYRICS',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: AppColors.activeLine,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Changes are saved to the library',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              color: AppColors.sectionHeader,
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
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 14,
          color: AppColors.activeLine,
          height: 1.7,
        ),
        decoration: InputDecoration(
          hintText: 'Type lyrics here…\n\nUse [Verse 1], [Chorus] etc. for section headers.',
          hintStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 13,
            color: AppColors.dimmedLine,
          ),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      color: AppColors.surface,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            _saving ? 'Saving…' : 'Apply & Save',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
