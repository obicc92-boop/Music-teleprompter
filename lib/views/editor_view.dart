import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/script.dart';
import '../models/script_formatting.dart';
import '../models/setlist_models.dart';
import '../services/formatting_service.dart';
import '../services/script_parser.dart';
import '../services/file_service.dart';
import '../services/pending_saves.dart';
import '../services/setlist_service.dart';
import '../services/song_library.dart';
import '../utils/app_platform.dart';
import '../utils/back_dispatcher.dart';
import '../utils/constants.dart';
import '../utils/same_path.dart';
import '../widgets/formatted_text.dart';
import '../widgets/formatted_text_controller.dart';
import '../widgets/lyrics_format_toolbar.dart';

class EditorView extends StatefulWidget {
  final Script initialScript;
  final void Function(Script script) onLaunchTeleprompter;
  final VoidCallback onBack;

  /// True when editing a song already in the library (opened from a setlist).
  final bool isLibrarySong;

  /// Where Android's back gesture is sent while the editor is open.
  final BackDispatcher? backDispatcher;

  /// The song was given a new title; setlists on disk already follow it,
  /// this lets the owner update the copy it holds in memory.
  final void Function(String from, String to, String path)? onSongRenamed;

  const EditorView({
    super.key,
    required this.initialScript,
    required this.onLaunchTeleprompter,
    required this.onBack,
    this.isLibrarySong = false,
    this.backDispatcher,
    this.onSongRenamed,
  });

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  late final FormattedTextController _textController;
  late final TextEditingController _titleController;
  late final FileService _fileService;
  final _formattingService = FormattingService();
  // Taps on the formatting toolbar count as taps in the lyrics, so the
  // selection survives them
  final _lyricsTapGroup = Object();
  String _lastText = '';
  ScriptFormatting _lastFormatting = ScriptFormatting.empty;
  Script _previewScript = Script.empty();
  String _currentTitle = 'Untitled';
  Timer? _parseDebounce;
  bool _showPreview = false; // phones show lyrics or preview, not both

  // Everything is saved by itself, a moment after it changes. What's on
  // disk is remembered so only real changes are written.
  Timer? _saveDebounce;
  Future<String?>? _saveInFlight;
  bool _saveAgain = false; // changed while a save was running
  Object? _saveError;
  String _savedText = '';
  ScriptFormatting _savedFormatting = ScriptFormatting.empty;
  String? _savedPath;

  // Title of the library song this editor saves to; null until a new
  // script is saved for the first time. The title as typed may differ from
  // it when another song already had that name ("Lalala" → "Lalala 2").
  String? _savedTitle;
  String? _savedTypedTitle;

  // How the song was when it was opened, for Revert
  late final String _openedText;
  late final String _openedTitle;
  ScriptFormatting _openedFormatting = ScriptFormatting.empty;

  static const _defaultTitle = 'Untitled';
  static const _saveAfterTyping = Duration(seconds: 1);
  // A new title renames the song everywhere, so it waits a little longer
  static const _saveAfterTitle = Duration(seconds: 2);

  bool get _isDirty =>
      _textController.text != _savedText ||
      !identical(_textController.formatting, _savedFormatting) ||
      _currentTitle.trim() != (_savedTypedTitle ?? _currentTitle.trim());

  bool get _changedSinceOpened =>
      _textController.text != _openedText ||
      _currentTitle.trim() != _openedTitle ||
      !_textController.formatting.sameAs(_openedFormatting);

  @override
  void initState() {
    super.initState();
    _fileService = FileService();
    _currentTitle = widget.initialScript.title;
    if (widget.isLibrarySong) {
      _savedTitle = _currentTitle;
      _savedTypedTitle = _currentTitle;
      _savedText = widget.initialScript.rawText;
    }
    _openedText = widget.initialScript.rawText;
    _openedTitle = _currentTitle;
    _textController = FormattedTextController(
      text: widget.initialScript.rawText,
    );
    _savedFormatting = _textController.formatting;
    _openedFormatting = _textController.formatting;
    _lastText = widget.initialScript.rawText;
    _titleController = TextEditingController(text: _currentTitle);
    _previewScript = widget.initialScript;
    _textController.addListener(_onTextChanged);
    _loadFormatting();

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

    _titleFocus.addListener(_onTitleFocusChanged);
    PendingSaves.register(_flushPending);
    widget.backDispatcher?.register(_goHome);
  }

  final _titleFocus = FocusNode();

  @override
  void dispose() {
    widget.backDispatcher?.unregister(_goHome);
    PendingSaves.unregister(_flushPending);
    _saveDebounce?.cancel();
    _parseDebounce?.cancel();
    _textController.dispose();
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _loadFormatting() async {
    if (widget.initialScript.isEmpty) return;
    final loaded = await _formattingService.load(_currentTitle);
    if (!mounted || loaded.isEmpty) return;
    final formatting = loaded.upgraded(widget.initialScript);
    _lastFormatting = formatting;
    _savedFormatting = formatting;
    _openedFormatting = formatting;
    _textController.formatting = formatting;
    setState(() {});
  }

  // The controller also reports caret moves; only real changes count
  void _onTextChanged() {
    final textChanged = _textController.text != _lastText;
    final formatChanged = !identical(
      _textController.formatting,
      _lastFormatting,
    );
    _lastText = _textController.text;
    _lastFormatting = _textController.formatting;
    if (!textChanged && !formatChanged) {
      setState(() {}); // the toolbar follows the selection
      return;
    }
    setState(() => _saveError = null);
    _scheduleSave(_saveAfterTyping);
    if (textChanged) {
      _parseDebounce?.cancel();
      _parseDebounce = Timer(const Duration(milliseconds: 400), _reparseScript);
    }
  }

  void _reparseScript() {
    final parsed = ScriptParser.parse(
      _textController.text,
      title: _currentTitle,
    );
    if (mounted) setState(() => _previewScript = parsed);
  }

  void _scheduleSave(Duration after) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(after, _autosave);
  }

  // A new title takes effect once the field is left, or after a pause
  void _onTitleFocusChanged() {
    if (!mounted) return;
    setState(() {}); // the field's border follows focus
    if (_titleFocus.hasFocus) return;
    if (_isDirty) {
      _autosave();
    } else if (_savedTitle != null && _currentTitle.trim() != _savedTitle) {
      // The name was taken, so the song was saved as "Title 2"
      _setTitleField(_savedTitle!);
    }
  }

  void _setTitleField(String title) {
    _titleController.text = title;
    _currentTitle = title;
    _savedTypedTitle = title;
  }

  /// Saves whatever changed. One save runs at a time; a change made while
  /// one is running is saved right after it.
  Future<void> _autosave() async {
    _saveDebounce?.cancel();
    if (_saveInFlight != null) {
      _saveAgain = true;
      return;
    }
    if (!_isDirty) return;
    final save = _save();
    _saveInFlight = save;
    try {
      await save;
    } finally {
      _saveInFlight = null;
    }
    if (_saveAgain) {
      _saveAgain = false;
      if (mounted && _isDirty) _scheduleSave(_saveAfterTyping);
    }
  }

  /// Everything typed so far is on disk when this completes. Returns the
  /// song's file, or null when there are no lyrics to save.
  Future<String?> _flushPending() async {
    _saveDebounce?.cancel();
    while (_saveInFlight != null) {
      await _saveInFlight;
    }
    if (!_isDirty) return _savedPath;
    final save = _save();
    _saveInFlight = save;
    try {
      return await save;
    } finally {
      _saveInFlight = null;
    }
  }

  /// Saves the lyrics to the song in the library and returns its file path,
  /// or null when there is nothing to save. A new song, or one given a new
  /// title, never overwrites a different song with the same name.
  Future<String?> _save() async {
    final text = _textController.text;
    final formatting = _textController.formatting;
    if (text.trim().isEmpty) return null;
    final typed = _currentTitle.trim().isEmpty
        ? _defaultTitle
        : _currentTitle.trim();
    final previous = _savedTitle;
    var title = typed;
    if (mounted) setState(() => _saveError = null);
    try {
      if (title != previous) {
        title = await _fileService.uniqueLibraryTitle(title, keeping: previous);
      }
      final String path;
      if (previous != null && title != previous) {
        // A rename: the song's settings and its setlist entries follow it,
        // instead of a second song appearing under the new name
        path = await SongLibrary.rename(
          from: previous,
          to: title,
          content: text,
        );
        widget.onSongRenamed?.call(previous, title, path);
      } else {
        path = await _fileService.saveToLibrary(text, title);
      }
      await _formattingService.save(title, formatting);
      _savedTitle = title;
      _savedPath = path;
      _savedText = text;
      _savedFormatting = formatting;
      _savedTypedTitle = typed;
      if (mounted) {
        // A title made unique shows in the field, unless it's being typed in
        if (title != typed && !_titleFocus.hasFocus) _setTitleField(title);
        setState(() {});
      }
      return path;
    } catch (e) {
      if (mounted) setState(() => _saveError = e);
      return null;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Leaving never drops edits: anything not yet written is saved first.
  Future<void> _goHome() async {
    await _flushPending();
    widget.onBack();
  }

  /// Puts the song back as it was when the editor was opened.
  Future<void> _revert() async {
    final blank = _openedText.trim().isEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          blank ? 'Throw this song away?' : 'Go back to how it was?',
        ),
        content: Text(
          blank
              ? 'Everything written here since you started is removed, '
                    'and the song leaves your library.'
              : 'Every change made since you opened "$_openedTitle" is '
                    'undone, including the title.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(blank ? 'Throw away' : 'Go back'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _saveDebounce?.cancel();
    while (_saveInFlight != null) {
      await _saveInFlight;
    }
    _titleController.text = _openedTitle;
    _currentTitle = _openedTitle;
    _lastText = _openedText;
    _lastFormatting = _openedFormatting;
    _textController.value = TextEditingValue(
      text: _openedText,
      selection: TextSelection.collapsed(offset: _openedText.length),
    );
    _textController.formatting = _openedFormatting;
    _reparseScript();
    if (blank) {
      // A song that started empty goes away again
      final title = _savedTitle;
      final path = _savedPath;
      if (title != null && path != null) {
        await SongLibrary.delete(title: title, path: path);
      }
      _savedTitle = null;
      _savedTypedTitle = null;
      _savedPath = null;
      _savedText = '';
      _savedFormatting = _textController.formatting;
      if (mounted) setState(() {});
      return;
    }
    await _flushPending();
  }

  Future<void> _openFile() async {
    final result = await _fileService.openFile();
    if (result == null) return;
    setState(() {
      _currentTitle = result.title;
      _textController.text = ScriptParser.normaliseLineBreaks(result.content);
      _textController.formatting = ScriptFormatting.empty;
    });
    _titleController.text = result.title;
    _reparseScript();
    _scheduleSave(_saveAfterTyping); // becomes a song in the library
  }

  Future<void> _exportFile() async {
    await _fileService.saveFile(_textController.text, _currentTitle);
  }

  Future<void> _addToSetlist() async {
    final path = await _flushPending();
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
          content: Text(
            'Saved to library. Create a setlist on the home screen to add it.',
          ),
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
    final alreadyIn =
        target.items.any((i) => i.isSong && samePath(i.path, path));
    if (!alreadyIn) {
      final item = SetlistItem.song(path: path, title: _currentTitle);
      final updated = target.copyWith(items: [...target.items, item]);
      final newSetlists = setlists
          .map((s) => s.id == updated.id ? updated : s)
          .toList();
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
    await _flushPending();
    if (!mounted) return;
    // Parsed after saving, which may have given a new song a unique title
    widget.onLaunchTeleprompter(
      ScriptParser.parse(_textController.text, title: _currentTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                _buildPhoneToolbar(),
                Expanded(
                  child: _showPreview ? _buildPreview() : _buildEditor(),
                ),
              ],
            );
          }
          return Column(
            children: [
              _buildToolbar(),
              Expanded(child: _buildBody()),
            ],
          );
        },
      ),
    );
  }

  // Two rows: title and launch, then lyrics/preview and the file actions
  Widget _buildPhoneToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back — everything is saved',
                onPressed: _goHome,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(child: _titleField()),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Launch',
                onPressed: _launch,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Lyrics')),
                  ButtonSegment(value: true, label: Text('Preview')),
                ],
                selected: {_showPreview},
                onSelectionChanged: (s) {
                  FocusScope.of(context).unfocus();
                  setState(() => _showPreview = s.first);
                },
                style: SegmentedButton.styleFrom(
                  foregroundColor: AppColors.uiText,
                  selectedForegroundColor: AppColors.textPrimary,
                  selectedBackgroundColor: AppColors.surfaceSelected,
                  side: const BorderSide(color: AppColors.border),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Spacer(),
              _saveStatus(),
              const SizedBox(width: 4),
              PopupMenuButton<VoidCallback>(
                tooltip: 'More',
                onSelected: (action) => action(),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.uiText,
                ),
                itemBuilder: (_) => [
                  _phoneMenuItem(
                    Icons.library_add_rounded,
                    'Add to a setlist',
                    _addToSetlist,
                  ),
                  _phoneMenuItem(
                    Icons.folder_open_rounded,
                    'Open a lyrics file',
                    _openFile,
                  ),
                  _phoneMenuItem(
                    Icons.ios_share_rounded,
                    'Save a copy as a file',
                    _exportFile,
                  ),
                  if (_changedSinceOpened)
                    _phoneMenuItem(
                      Icons.history_rounded,
                      'Go back to how it was',
                      _revert,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<VoidCallback> _phoneMenuItem(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.uiText),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 15)),
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
                tooltip: 'Back to setlists — everything is saved',
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
                tooltip: 'Add this song to a setlist',
                onTap: _addToSetlist,
              ),
              if (_changedSinceOpened) ...[
                const SizedBox(width: 8),
                _toolbarButton(
                  compact: compact,
                  icon: Icons.history_rounded,
                  label: 'Revert',
                  tooltip: 'Go back to how the song was when you opened it',
                  onTap: _revert,
                ),
              ],
              const SizedBox(width: 16),
              Expanded(child: _titleField()),
              const SizedBox(width: 12),
              _saveStatus(),
              const SizedBox(width: 12),
              _launchButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _titleField() {
    return Tooltip(
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
                // A new title is a change to save, like new words
                onChanged: (v) {
                  setState(() => _currentTitle = v);
                  _scheduleSave(_saveAfterTitle);
                },
              ),
            ),
          ],
        ),
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
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Container(
      color: AppColors.background,
      padding: narrow
          ? const EdgeInsets.fromLTRB(20, 16, 16, 8)
          : const EdgeInsets.fromLTRB(32, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LYRICS', style: AppTextStyles.eyebrow),
          const SizedBox(height: 6),
          const Text(
            'Sections: use the Section button, or put [Verse 1], (Chorus), Chorus: or # Chorus on its own line',
            style: TextStyle(
              fontFamily: AppTextStyles.ui,
              fontSize: 13,
              color: AppColors.uiHint,
            ),
          ),
          const SizedBox(height: 12),
          LyricsFormatToolbar(
            controller: _textController,
            tapGroup: _lyricsTapGroup,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CallbackShortcuts(
              bindings: _formatShortcuts(),
              child: TextField(
                controller: _textController,
                groupId: _lyricsTapGroup,
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
                  hintText:
                      '[Intro | 4 bars]\n\nYour lyrics here...\n\n[Verse 1]\n\nLine one\nLine two',
                  hintStyle: TextStyle(
                    fontFamily: AppTextStyles.mono,
                    color: AppColors.uiMuted,
                  ),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ctrl on Windows, ⌘ on a Mac
  Map<ShortcutActivator, VoidCallback> _formatShortcuts() {
    final mac =
        AppPlatform.isDesktop && defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, control: !mac, meta: mac);
    return {
      key(LogicalKeyboardKey.keyB): _textController.toggleBold,
      key(LogicalKeyboardKey.bracketRight): () =>
          _textController.stepFontSize(1),
      key(LogicalKeyboardKey.bracketLeft): () =>
          _textController.stepFontSize(-1),
      key(LogicalKeyboardKey.backslash): _textController.clearStyle,
    };
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
                      const style = TextStyle(
                        fontFamily: AppTextStyles.mono,
                        fontSize: 13,
                        color: AppColors.uiText,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text.rich(
                          TextSpan(
                            children: formattedSpans(
                              line.text,
                              _textController.formatting.forLine(line),
                              style,
                            ),
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

  /// "Saved", "Saving…", or what went wrong: the word that replaces a
  /// Save button, so it's clear nothing needs pressing.
  Widget _saveStatus() {
    final error = _saveError;
    final nothingYet =
        _savedPath == null && _textController.text.trim().isEmpty;
    final IconData icon;
    final String label;
    final String tooltip;
    final Color color;
    if (error != null) {
      icon = Icons.error_outline_rounded;
      label = 'Not saved';
      tooltip = "Couldn't save: $error\nIt's tried again with the next change.";
      color = AppColors.danger;
    } else if (nothingYet) {
      icon = Icons.edit_note_rounded;
      label = 'Saves as you type';
      tooltip = 'The song joins your library with the first words';
      color = AppColors.uiMuted;
    } else if (_saveInFlight != null || _isDirty) {
      icon = Icons.sync_rounded;
      label = 'Saving…';
      tooltip = 'Changes are saved a moment after you stop typing';
      color = AppColors.uiHint;
    } else {
      icon = Icons.check_rounded;
      label = 'Saved';
      tooltip = "Everything is saved to your library — there's nothing to press";
      color = AppColors.uiHint;
    }
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.ui,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
          children: setlists
              .map(
                (s) => ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                ),
              )
              .toList(),
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
