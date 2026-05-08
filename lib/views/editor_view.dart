import 'dart:async';
import 'package:flutter/material.dart';
import '../models/script.dart';
import '../models/setlist_models.dart';
import '../services/script_parser.dart';
import '../services/file_service.dart';
import '../services/setlist_service.dart';
import '../utils/constants.dart';

class EditorView extends StatefulWidget {
  final Script initialScript;
  final void Function(Script script) onLaunchTeleprompter;
  final VoidCallback onBack;

  const EditorView({
    super.key,
    required this.initialScript,
    required this.onLaunchTeleprompter,
    required this.onBack,
  });

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  late final TextEditingController _textController;
  late final TextEditingController _titleController;
  late final FileService _fileService;
  Script _previewScript = Script.empty();
  String _currentTitle = 'Untitled';
  Timer? _autosaveTimer;
  Timer? _parseDebounce;
  bool _isDirty = false;

  static const _defaultTitle = 'Untitled';

  @override
  void initState() {
    super.initState();
    _fileService = FileService();
    _currentTitle = widget.initialScript.title;
    _textController = TextEditingController(text: widget.initialScript.rawText);
    _titleController = TextEditingController(text: _currentTitle);
    _previewScript = widget.initialScript;
    _textController.addListener(_onTextChanged);

    // Auto-select the title and focus it so the user immediately knows to rename
    if (_currentTitle == _defaultTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _titleController.text.length,
        );
        FocusScope.of(context).requestFocus(_titleFocus);
      });
    }

    _scheduleAutosave();
  }

  final _titleFocus = FocusNode();

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _parseDebounce?.cancel();
    _textController.dispose();
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _isDirty = true);
    _parseDebounce?.cancel();
    _parseDebounce = Timer(const Duration(milliseconds: 400), _reparseScript);
  }

  void _reparseScript() {
    final parsed = ScriptParser.parse(
      _textController.text,
      title: _currentTitle,
    );
    if (mounted) setState(() => _previewScript = parsed);
  }

  void _scheduleAutosave() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isDirty) _autosave();
    });
  }

  Future<void> _autosave() async {
    await _fileService.autosave(_textController.text, _currentTitle);
    if (mounted) setState(() => _isDirty = false);
  }

  Future<void> _openFile() async {
    final result = await _fileService.openFile();
    if (result == null) return;
    setState(() {
      _currentTitle = result.title;
      _textController.text = result.content;
      _isDirty = false;
    });
    _titleController.text = result.title;
    _reparseScript();
  }

  Future<void> _saveFile() async {
    await _fileService.saveFile(_textController.text, _currentTitle);
    if (mounted) setState(() => _isDirty = false);
  }

  Future<void> _saveToLibrary() async {
    final path = await _fileService.saveToLibrary(_textController.text, _currentTitle);
    if (!mounted) return;

    final setlists = await SetlistService().load();
    if (!mounted) return;

    if (setlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to library. Create a setlist on the home screen to add it.'),
          backgroundColor: AppColors.surface,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Pick which setlist to add to (skip dialog if only one exists)
    Setlist target;
    if (setlists.length == 1) {
      target = setlists.first;
    } else {
      final picked = await showDialog<Setlist>(
        context: context,
        builder: (_) => _SetlistPickerDialog(setlists: setlists),
      );
      if (picked == null || !mounted) return;
      target = picked;
    }

    // Skip if already in the setlist (same path)
    final alreadyIn = target.items.any((i) => i.isSong && i.path == path);
    if (!alreadyIn) {
      final item = SetlistItem.song(path: path, title: _currentTitle);
      final updated = target.copyWith(items: [...target.items, item]);
      final newSetlists = setlists.map((s) => s.id == updated.id ? updated : s).toList();
      await SetlistService().save(newSetlists);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alreadyIn
              ? '"$_currentTitle" is already in ${target.name}.'
              : 'Added "$_currentTitle" to ${target.name}.',
        ),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _launch() {
    final script = ScriptParser.parse(_textController.text, title: _currentTitle);
    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script is empty — add some lyrics first.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    _fileService.saveToLibrary(_textController.text, _currentTitle);
    widget.onLaunchTeleprompter(script);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 52,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _toolbarButton(
            icon: Icons.arrow_back_rounded,
            label: 'Home',
            onTap: widget.onBack,
          ),
          const SizedBox(width: 8),
          _toolbarButton(
            icon: Icons.folder_open_rounded,
            label: 'Open',
            onTap: _openFile,
          ),
          const SizedBox(width: 8),
          _toolbarButton(
            icon: Icons.save_rounded,
            label: _isDirty ? 'Save*' : 'Save',
            onTap: _saveFile,
          ),
          const SizedBox(width: 8),
          _toolbarButton(
            icon: Icons.library_add_rounded,
            label: 'Save to Setlist',
            onTap: _saveToLibrary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Tooltip(
              message: 'Song title — shown in the setlist and teleprompter',
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _titleFocus.hasFocus
                        ? AppColors.accent.withValues(alpha: 0.6)
                        : AppColors.surfaceElevated,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.background, width: 1),
                        ),
                      ),
                      child: const Text(
                        'TITLE',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sectionHeader,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        decoration: const InputDecoration(
                          hintText: 'Enter song title...',
                          hintStyle: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            color: AppColors.dimmedLine,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 13,
                          color: AppColors.activeLine,
                        ),
                        onChanged: (v) => setState(() => _currentTitle = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _launchButton(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildEditor()),
        Container(width: 1, color: AppColors.surfaceElevated),
        Expanded(flex: 2, child: _buildPreview()),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCRIPT EDITOR',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              color: AppColors.sectionHeader,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use [Section Name] or [Verse 1 | 4 bars] for sections',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              color: AppColors.dimmedLine,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 15,
                color: AppColors.activeLine,
                height: 1.7,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '[Intro | 4 bars]\n\nYour lyrics here...\n\n[Verse 1]\n\nLine one\nLine two',
                hintStyle: TextStyle(color: AppColors.dimmedLine),
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              'PREVIEW  ·  ${_previewScript.totalLines} LINES  ·  ${_previewScript.sections.length} SECTIONS',
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 10,
                color: AppColors.sectionHeader,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: _previewScript.isEmpty
                ? const Center(
                    child: Text(
                      'Start typing to preview...',
                      style: TextStyle(color: AppColors.dimmedLine),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _previewScript.allLines.length,
                    itemBuilder: (ctx, i) {
                      final line = _previewScript.allLines[i];
                      if (line.isSectionHeader) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '▸ ${line.sectionLabel}',
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 11,
                              color: AppColors.accent,
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      }
                      if (line.isEmpty) return const SizedBox(height: 6);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          line.text,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 13,
                            color: AppColors.inactiveLine,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.sectionHeader),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          color: AppColors.sectionHeader,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  Widget _launchButton() {
    return ElevatedButton.icon(
      onPressed: _launch,
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text(
        'LAUNCH',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SetlistPickerDialog extends StatelessWidget {
  final List<Setlist> setlists;
  const _SetlistPickerDialog({required this.setlists});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Add to Setlist',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.activeLine,
          fontSize: 15,
        ),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: setlists.map((s) => ListTile(
            dense: true,
            title: Text(
              s.name,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                color: AppColors.activeLine,
                fontSize: 13,
              ),
            ),
            trailing: Text(
              '${s.items.where((i) => i.isSong).length} songs',
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                color: AppColors.sectionHeader,
                fontSize: 11,
              ),
            ),
            onTap: () => Navigator.pop(context, s),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.sectionHeader)),
        ),
      ],
    );
  }
}
