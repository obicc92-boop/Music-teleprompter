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

  /// True when editing a song already in the library (opened from a setlist).
  final bool isLibrarySong;

  const EditorView({
    super.key,
    required this.initialScript,
    required this.onLaunchTeleprompter,
    required this.onBack,
    this.isLibrarySong = false,
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

  // Title of the library song this editor saves to; null until a new
  // script is saved for the first time.
  String? _savedTitle;

  static const _defaultTitle = 'Untitled';

  @override
  void initState() {
    super.initState();
    _fileService = FileService();
    _currentTitle = widget.initialScript.title;
    if (widget.isLibrarySong) _savedTitle = _currentTitle;
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
      // Not while the title is being typed, so a half-typed title isn't saved
      if (_isDirty && !_titleFocus.hasFocus) _save();
    });
  }

  /// Saves the lyrics to the song in the library and returns its file path,
  /// or null when there is nothing to save. A new song, or one given a new
  /// title, never overwrites a different song with the same name.
  Future<String?> _save() async {
    if (_textController.text.trim().isEmpty) return null;
    var title = _currentTitle.trim().isEmpty ? _defaultTitle : _currentTitle.trim();
    if (title != _savedTitle) {
      title = await _fileService.uniqueLibraryTitle(title);
    }
    final path = await _fileService.saveToLibrary(_textController.text, title);
    _savedTitle = title;
    if (mounted) {
      if (title != _currentTitle) _titleController.text = title;
      setState(() {
        _currentTitle = title;
        _isDirty = false;
      });
    }
    return path;
  }

  void _showSnack(String message, [ScaffoldMessengerState? messenger]) {
    (messenger ?? ScaffoldMessenger.of(context)).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _saveNow() async {
    final saved = await _save() != null;
    if (!mounted) return;
    _showSnack(saved
        ? 'Saved "$_currentTitle".'
        : 'Nothing to save — add some lyrics first.');
  }

  // Leaving never drops edits: unsaved changes are saved first.
  Future<void> _goHome() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isDirty && await _save() != null) {
      _showSnack('Saved "$_currentTitle".', messenger);
    }
    widget.onBack();
  }

  Future<void> _openFile() async {
    final result = await _fileService.openFile();
    if (result == null) return;
    setState(() {
      _currentTitle = result.title;
      _textController.text = result.content;
      _isDirty = true; // becomes a song in the library when saved
    });
    _titleController.text = result.title;
    _reparseScript();
  }

  Future<void> _exportFile() async {
    await _fileService.saveFile(_textController.text, _currentTitle);
  }

  Future<void> _addToSetlist() async {
    final path = await _save();
    if (!mounted) return;
    if (path == null) {
      _showSnack('Nothing to save — add some lyrics first.');
      return;
    }

    final setlists = await SetlistService().load();
    if (!mounted) return;

    if (setlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to library. Create a setlist on the home screen to add it.'),
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launch() async {
    if (ScriptParser.parse(_textController.text).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script is empty — add some lyrics first.'),
        ),
      );
      return;
    }
    await _save();
    if (!mounted) return;
    // Parsed after saving, which may have given a new song a unique title
    widget.onLaunchTeleprompter(
        ScriptParser.parse(_textController.text, title: _currentTitle));
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
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Narrow windows get icon-only buttons so the title field keeps room
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1000;
          return Row(
            children: [
              _toolbarButton(
                compact: compact,
                icon: Icons.arrow_back_rounded,
                label: 'Home',
                tooltip: 'Back to setlists — unsaved changes are saved',
                onTap: _goHome,
              ),
              const SizedBox(width: 8),
              _toolbarButton(
                compact: compact,
                icon: Icons.folder_open_rounded,
                label: 'Open',
                tooltip: 'Open a lyrics file from disk',
                onTap: _openFile,
              ),
              const SizedBox(width: 8),
              _toolbarButton(
                compact: compact,
                icon: Icons.save_rounded,
                label: _isDirty ? 'Save*' : 'Save',
                showDot: _isDirty,
                tooltip: _isDirty
                    ? 'Unsaved changes — also saved automatically'
                    : 'Saved to your song library',
                onTap: _saveNow,
              ),
              const SizedBox(width: 8),
              _toolbarButton(
                compact: compact,
                icon: Icons.ios_share_rounded,
                label: 'Export',
                tooltip: 'Save a copy as a file anywhere on disk',
                onTap: _exportFile,
              ),
              const SizedBox(width: 8),
              _toolbarButton(
                compact: compact,
                icon: Icons.library_add_rounded,
                label: 'Add to Setlist',
                tooltip: 'Save and add this song to a setlist',
                onTap: _addToSetlist,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Tooltip(
                  message: 'Song title — shown in the setlist and teleprompter',
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _titleFocus.hasFocus
                            ? AppColors.accent.withValues(alpha: 0.7)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.hairline, width: 1),
                            ),
                          ),
                          child: const Text('TITLE', style: AppTextStyles.eyebrow),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocus,
                            decoration: const InputDecoration(
                              hintText: 'Song title',
                              hintStyle: TextStyle(
                                fontFamily: AppTextStyles.ui,
                                color: AppColors.uiMuted,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            style: const TextStyle(
                              fontFamily: AppTextStyles.ui,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
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
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildEditor()),
        Container(width: 1, color: AppColors.hairline),
        Expanded(flex: 2, child: _buildPreview()),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LYRICS', style: AppTextStyles.eyebrow),
          const SizedBox(height: 6),
          const Text(
            'Put sections on their own line: [Verse 1], [Chorus], or [Intro | 4 bars]',
            style: TextStyle(
              fontFamily: AppTextStyles.ui,
              fontSize: 13,
              color: AppColors.uiHint,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: AppTextStyles.mono,
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.7,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '[Intro | 4 bars]\n\nYour lyrics here...\n\n[Verse 1]\n\nLine one\nLine two',
                hintStyle: TextStyle(fontFamily: AppTextStyles.mono, color: AppColors.uiMuted),
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
      color: AppColors.sidebar,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            alignment: Alignment.centerLeft,
            child: Text(
              'PREVIEW  ·  ${_previewScript.totalLines} LINES  ·  ${_previewScript.sections.length} SECTIONS',
              style: AppTextStyles.eyebrow,
            ),
          ),
          Expanded(
            child: _previewScript.isEmpty
                ? const Center(
                    child: Text(
                      'Start typing to see the preview',
                      style: TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 14,
                        color: AppColors.uiHint,
                      ),
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
                              fontFamily: AppTextStyles.mono,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentText,
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
                            fontFamily: AppTextStyles.mono,
                            fontSize: 13,
                            color: AppColors.uiText,
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
    required bool compact,
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    if (compact) {
      return Tooltip(
        message: '$label — $tooltip',
        child: IconButton(
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Badge(
            isLabelVisible: showDot,
            smallSize: 7,
            backgroundColor: AppColors.accent,
            child: Icon(icon, size: 18, color: AppColors.uiHint),
          ),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: AppColors.uiHint),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTextStyles.ui,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.uiText,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _launchButton() {
    return ElevatedButton.icon(
      onPressed: _launch,
      icon: const Icon(Icons.play_arrow_rounded, size: 20),
      label: const Text('Launch'),
    );
  }
}

class _SetlistPickerDialog extends StatelessWidget {
  final List<Setlist> setlists;
  const _SetlistPickerDialog({required this.setlists});

  static String _songCount(int n) => n == 1 ? '1 song' : '$n songs';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to a setlist'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: setlists.map((s) => ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            title: Text(
              s.name,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text(
              _songCount(s.items.where((i) => i.isSong).length),
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                color: AppColors.uiHint,
                fontSize: 12,
              ),
            ),
            onTap: () => Navigator.pop(context, s),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
