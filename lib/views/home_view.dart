import 'package:flutter/material.dart';
import '../models/script.dart';
import '../models/setlist_models.dart';
import '../services/file_service.dart';
import '../services/script_parser.dart';
import '../services/setlist_service.dart';
import '../utils/constants.dart';

const _palette = [
  0xFF555555,
  0xFFFF6B35,
  0xFF4FC3F7,
  0xFF66BB6A,
  0xFFAB47BC,
  0xFFEF5350,
  0xFFFFD700,
  0xFF26C6DA,
  0xFFEC407A,
  0xFF78909C,
];

const String _exampleScript = '''[Intro | 4 bars]

[Verse 1]
Standing at the edge of the night
Every beat drops like a heartbeat ignite
Voices calling out from the crowd
We came to play, we came to be loud

[Pre-Chorus]
Feel it in the bass
Feel it in the floor
You know we came to give you something more

[Chorus]
Let the music take control tonight
Lose yourself and find the light
Every lyric, every line
This moment is yours and mine

[Verse 2]
The city glows beneath our feet
Every soul in sync with the beat
Lift your voice and harmonize
Let the music fill the skies

[Pre-Chorus]
Feel it in the bass
Feel it in the floor
You know we came to give you something more

[Chorus]
Let the music take control tonight
Lose yourself and find the light
Every lyric, every line
This moment is yours and mine

[Bridge | 8 bars]
We rise we fall we find our way
Through every night into the day
The stage is set the lights are on
Together now we carry on

[Outro]
Let the music take control
Let the music take control
Let the music take control tonight
''';

class HomeView extends StatefulWidget {
  final void Function(Script) onOpenScript;
  final void Function(Script, List<SetlistEntry>, int) onLaunchScript;

  const HomeView({
    super.key,
    required this.onOpenScript,
    required this.onLaunchScript,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _setlistService = SetlistService();
  final _fileService = FileService();

  List<Setlist> _setlists = [];
  int _activeTab = 0;
  bool _loading = true;
  bool _importing = false;

  // Inline editing state (one item at a time)
  String? _editingId;
  final _editCtrl = TextEditingController();
  final _editFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _editFocus.addListener(() {
      if (!_editFocus.hasFocus) _commitEdit();
    });
    _load();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  Setlist? get _active => _setlists.isEmpty
      ? null
      : _setlists[_activeTab.clamp(0, _setlists.length - 1)];

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final setlists = await _setlistService.load();
    if (mounted) {
      setState(() {
        _setlists = setlists;
        _activeTab = _activeTab.clamp(0, (setlists.length - 1).clamp(0, 9999));
        _loading = false;
      });
    }
  }

  Future<void> _save() => _setlistService.save(_setlists);

  void _updateActiveItems(List<SetlistItem> items) {
    if (_active == null) return;
    setState(() => _setlists[_activeTab] = _active!.copyWith(items: items));
    _save();
  }

  void _replaceItem(SetlistItem replacement) {
    if (_active == null) return;
    final items = _active!.items
        .map((i) => i.id == replacement.id ? replacement : i)
        .toList();
    _updateActiveItems(items);
  }

  // ── Setlist management ────────────────────────────────────────────────────

  Future<void> _addSetlist() async {
    final name = await _promptText('New Setlist', 'Setlist name', '');
    if (name == null || name.trim().isEmpty) return;
    final setlist = Setlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      items: const [],
    );
    setState(() {
      _setlists.add(setlist);
      _activeTab = _setlists.length - 1;
    });
    _save();
  }

  Future<void> _renameSetlist() async {
    if (_active == null) return;
    final name = await _promptText('Rename Setlist', 'Setlist name', _active!.name);
    if (name == null || name.trim().isEmpty) return;
    setState(() => _setlists[_activeTab] = _active!.copyWith(name: name.trim()));
    _save();
  }

  Future<void> _deleteSetlist() async {
    if (_active == null || _setlists.length <= 1) return;
    final ok = await _confirm(
      'Delete "${_active!.name}"?',
      'This setlist will be removed. Songs in your library are not deleted.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    setState(() {
      _setlists.removeAt(_activeTab);
      _activeTab = _activeTab.clamp(0, _setlists.length - 1);
    });
    _save();
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    if (_active == null) return;
    if (newIndex > oldIndex) newIndex--;
    final items = List<SetlistItem>.from(_active!.items);
    items.insert(newIndex, items.removeAt(oldIndex));
    _updateActiveItems(items);
  }

  // ── Add song / separator ──────────────────────────────────────────────────

  Future<void> _showAddSong() async {
    if (_active == null) return;
    final songs = await _setlistService.librarySongs();
    if (!mounted) return;

    final picked = await showDialog<({String path, String title})>(
      context: context,
      builder: (_) => _LibraryPickerDialog(songs: songs),
    );
    if (picked == null) return;

    final item = SetlistItem.song(path: picked.path, title: picked.title);
    _updateActiveItems([..._active!.items, item]);
  }

  void _addSeparator() {
    if (_active == null) return;
    final item = SetlistItem.separator();
    _updateActiveItems([..._active!.items, item]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _beginEdit(item));
  }

  // ── Import file ───────────────────────────────────────────────────────────

  Future<void> _importFile() async {
    setState(() => _importing = true);
    final result = await _fileService.openFile();
    setState(() => _importing = false);
    if (result == null) return;
    await _fileService.saveToLibrary(result.content, result.title);
    if (!mounted) return;
    widget.onOpenScript(ScriptParser.parse(result.content, title: result.title));
  }

  // ── Colour picker ─────────────────────────────────────────────────────────

  Future<void> _pickColor(SetlistItem item) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => _ColorPickerDialog(current: item.colorValue),
    );
    if (selected == null) return;
    _replaceItem(item.copyWith(colorValue: selected));
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  Future<void> _pickSpeed(SetlistItem item) async {
    final result = await showDialog<_SpeedResult>(
      context: context,
      builder: (_) => _SpeedPickerDialog(current: item.speedMultiplier),
    );
    if (result == null) return; // cancelled
    _replaceItem(item.copyWith(speedMultiplier: result.speed));
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteItem(SetlistItem item) async {
    if (item.isSong) {
      final ok = await _confirm(
        'Remove "${item.title}"?',
        'The song will be removed from this setlist. The file stays in your library.',
        confirmLabel: 'Remove',
      );
      if (!ok) return;
    }
    if (_active == null) return;
    _updateActiveItems(_active!.items.where((i) => i.id != item.id).toList());
  }

  // ── Inline edit ───────────────────────────────────────────────────────────

  void _beginEdit(SetlistItem item) {
    if (_editingId != null) _commitEdit();
    setState(() => _editingId = item.id);
    _editCtrl.text = item.isSong ? item.note : item.text;
    _editCtrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _editCtrl.text.length);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _editFocus.requestFocus());
  }

  void _commitEdit() {
    if (_editingId == null || _active == null) return;
    final id = _editingId!;
    final value = _editCtrl.text;
    final item = _active!.items.where((i) => i.id == id).firstOrNull;
    if (item == null) {
      setState(() => _editingId = null);
      return;
    }
    final updated =
        item.isSong ? item.copyWith(note: value) : item.copyWith(text: value);
    setState(() => _editingId = null);
    _replaceItem(updated);
  }

  // ── Launch / open editor ──────────────────────────────────────────────────

  Future<void> _launchItem(SetlistItem item) async {
    final content = await _fileService.readSavedScript(item.path);
    if (!mounted) return;
    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('File not found — it may have been moved or deleted.'),
        backgroundColor: AppColors.surface,
      ));
      return;
    }
    final script = ScriptParser.parse(content, title: item.title);
    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Script is empty — open it to add lyrics first.'),
        backgroundColor: AppColors.surface,
      ));
      return;
    }
    final songs = _active!.items.where((i) => i.isSong).toList();
    final entries = songs
        .map((i) => (
              path: i.path,
              title: i.title,
              speedMultiplier: i.speedMultiplier,
            ))
        .toList();
    final index = songs.indexWhere((i) => i.id == item.id);
    widget.onLaunchScript(script, entries, index);
  }

  Future<void> _editItem(SetlistItem item) async {
    final content = await _fileService.readSavedScript(item.path);
    if (content == null || !mounted) return;
    widget.onOpenScript(ScriptParser.parse(content, title: item.title));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _buildContent()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, size: 26, color: AppColors.accent),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MUSIC TELEPROMPTER',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.activeLine,
                  letterSpacing: 3,
                ),
              ),
              Text(
                'Beat-synced lyrics for live performance',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 11,
                  color: AppColors.sectionHeader,
                ),
              ),
            ],
          ),
          const Spacer(),
          _headerBtn(
            icon: Icons.music_note_rounded,
            label: 'Load Example',
            onTap: () => widget.onOpenScript(
              ScriptParser.parse(_exampleScript, title: 'Example Song'),
            ),
          ),
          const SizedBox(width: 10),
          _headerBtn(
            icon: Icons.edit_note_rounded,
            label: 'New Script',
            onTap: () => widget.onOpenScript(Script.empty()),
          ),
          const SizedBox(width: 10),
          _headerBtn(
            icon: Icons.file_download_rounded,
            label: _importing ? 'Importing...' : 'Import File',
            onTap: _importing ? null : _importFile,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceElevated, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _setlists.length; i++) _buildTab(i),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'New setlist',
            child: InkWell(
              onTap: _addSetlist,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.add_rounded,
                    size: 16, color: AppColors.sectionHeader),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    final isActive = index == _activeTab;
    final setlist = _setlists[index];
    return GestureDetector(
      onTap: () {
        if (_editingId != null) _commitEdit();
        setState(() => _activeTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              setlist.name,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 12,
                color:
                    isActive ? AppColors.activeLine : AppColors.sectionHeader,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _renameSetlist,
                child: const Icon(Icons.edit_rounded,
                    size: 11, color: AppColors.dimmedLine),
              ),
              if (_setlists.length > 1) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: _deleteSetlist,
                  child: const Icon(Icons.close_rounded,
                      size: 11, color: AppColors.dimmedLine),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }

    final active = _active;
    if (active == null || active.items.isEmpty) {
      return _buildEmptyState();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
      itemCount: active.items.length,
      onReorder: _onReorder,
      proxyDecorator: (child, idx, anim) => Material(
        elevation: 8,
        color: Colors.transparent,
        shadowColor: Colors.black54,
        child: child,
      ),
      itemBuilder: (_, i) {
        final item = active.items[i];
        return item.isSong ? _buildSongCard(item) : _buildSeparatorCard(item);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.queue_music_rounded,
              size: 52, color: AppColors.dimmedLine),
          SizedBox(height: 16),
          Text(
            'This setlist is empty',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 16,
              color: AppColors.inactiveLine,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Click "Add Song" to add songs from your library,',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: AppColors.dimmedLine,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'or "Import File" to bring in a new .txt / .lrc file.',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: AppColors.dimmedLine,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(SetlistItem item) {
    final accent = Color(item.colorValue);
    final isEditing = _editingId == item.id;

    return Padding(
      key: ValueKey(item.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceElevated),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Colour dot
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Tooltip(
                    message: 'Change colour',
                    child: GestureDetector(
                      onTap: () => _pickColor(item),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title + note — tap to launch (or commit edit)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_editingId != null) {
                        _commitEdit();
                        return;
                      }
                      _launchItem(item);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 15,
                              color: AppColors.activeLine,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          isEditing
                              ? TextField(
                                  controller: _editCtrl,
                                  focusNode: _editFocus,
                                  style: const TextStyle(
                                    fontFamily: AppTextStyles.fontFamily,
                                    fontSize: 12,
                                    color: AppColors.inactiveLine,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Add a note...',
                                    hintStyle: TextStyle(
                                      fontFamily: AppTextStyles.fontFamily,
                                      fontSize: 12,
                                      color: AppColors.dimmedLine,
                                    ),
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (_) => _commitEdit(),
                                )
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _beginEdit(item),
                                  child: Text(
                                    item.note.isEmpty
                                        ? 'Add note...'
                                        : item.note,
                                    style: TextStyle(
                                      fontFamily: AppTextStyles.fontFamily,
                                      fontSize: 12,
                                      color: item.note.isEmpty
                                          ? AppColors.dimmedLine
                                          : AppColors.sectionHeader,
                                      fontStyle: item.note.isEmpty
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Edit button
                Tooltip(
                  message: 'Open in editor',
                  child: InkWell(
                    onTap: () => _editItem(item),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.edit_rounded,
                          size: 17, color: AppColors.sectionHeader),
                    ),
                  ),
                ),

                // Delete button
                Tooltip(
                  message: 'Remove from setlist',
                  child: InkWell(
                    onTap: () => _deleteItem(item),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 17, color: AppColors.sectionHeader),
                    ),
                  ),
                ),

                // Speed chip
                Tooltip(
                  message: item.speedMultiplier == null
                      ? 'Set song speed (using global default)'
                      : 'Song speed: ${item.speedMultiplier!.toStringAsFixed(2)}×  —  tap to change',
                  child: InkWell(
                    onTap: () => _pickSpeed(item),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      child: Text(
                        item.speedMultiplier == null
                            ? '⚡'
                            : '${item.speedMultiplier!.toStringAsFixed(2)}×',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 11,
                          color: item.speedMultiplier == null
                              ? AppColors.dimmedLine
                              : AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // LAUNCH button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _launchButton(accent, () => _launchItem(item)),
                ),

                // Drag handle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.drag_indicator_rounded,
                      size: 20, color: AppColors.dimmedLine),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeparatorCard(SetlistItem item) {
    final isEditing = _editingId == item.id;

    return Padding(
      key: ValueKey(item.id),
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.dimmedLine.withValues(alpha: 0.25),
          ),
          color: AppColors.background,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.notes_rounded,
                size: 14, color: AppColors.dimmedLine),
            const SizedBox(width: 12),

            // Separator text — editable
            Expanded(
              child: isEditing
                  ? TextField(
                      controller: _editCtrl,
                      focusNode: _editFocus,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 13,
                        color: AppColors.sectionHeader,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Stage note, break, band intro...',
                        hintStyle: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 13,
                          color: AppColors.dimmedLine,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _commitEdit(),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _beginEdit(item),
                      child: Text(
                        item.text.isEmpty
                            ? 'Tap to add a stage note...'
                            : item.text,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 13,
                          color: item.text.isEmpty
                              ? AppColors.dimmedLine
                              : AppColors.sectionHeader,
                          fontStyle: item.text.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
            ),

            InkWell(
              onTap: () => _deleteItem(item),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 14, color: AppColors.dimmedLine),
              ),
            ),

            const SizedBox(width: 4),

            Icon(Icons.drag_indicator_rounded,
                size: 18, color: AppColors.dimmedLine),
          ],
        ),
      ),
    );
  }

  Widget _launchButton(Color accent, VoidCallback onTap) {
    return Tooltip(
      message: 'Launch teleprompter',
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 17, color: Colors.black),
                SizedBox(width: 4),
                Text(
                  'LAUNCH',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceElevated),
        ),
      ),
      child: Row(
        children: [
          _footerBtn(
            icon: Icons.library_music_rounded,
            label: 'Add Song',
            onTap: _showAddSong,
            isPrimary: true,
          ),
          const SizedBox(width: 10),
          _footerBtn(
            icon: Icons.notes_rounded,
            label: 'Add Separator',
            onTap: _addSeparator,
          ),
          const Spacer(),
          const Text(
            'SPACE  play/pause  ·  ↑↓  speed  ·  ←→  jump section  ·  F  fullscreen  ·  N  next  ·  P  prev',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 10,
              color: AppColors.dimmedLine,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? AppColors.accent : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: isPrimary ? Colors.black : AppColors.sectionHeader),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.black : AppColors.sectionHeader,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? AppColors.accent : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: isPrimary ? Colors.black : AppColors.sectionHeader),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.black : AppColors.sectionHeader,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Utility dialogs ───────────────────────────────────────────────────────

  Future<String?> _promptText(String title, String hint, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            color: AppColors.activeLine,
            fontSize: 15,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            color: AppColors.activeLine,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.dimmedLine),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.sectionHeader)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            color: AppColors.activeLine,
            fontSize: 15,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            color: AppColors.sectionHeader,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.sectionHeader)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Speed picker ─────────────────────────────────────────────────────────────

class _SpeedResult {
  final double? speed; // null = use global default
  const _SpeedResult(this.speed);
}

class _SpeedPickerDialog extends StatefulWidget {
  final double? current;
  const _SpeedPickerDialog({required this.current});

  @override
  State<_SpeedPickerDialog> createState() => _SpeedPickerDialogState();
}

class _SpeedPickerDialogState extends State<_SpeedPickerDialog> {
  late double _value;
  late bool _useDefault;

  static const _presets = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _useDefault = widget.current == null;
    _value = widget.current ?? 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Song Speed',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.activeLine,
          fontSize: 15,
        ),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto toggle
            GestureDetector(
              onTap: () => setState(() => _useDefault = !_useDefault),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _useDefault
                          ? AppColors.accent
                          : AppColors.surfaceElevated,
                      border: Border.all(
                        color: _useDefault
                            ? AppColors.accent
                            : AppColors.sectionHeader,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Auto  (use global default speed)',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 13,
                      color: AppColors.inactiveLine,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((p) {
                final isSelected = !_useDefault &&
                    (_value - p).abs() < 0.01;
                return GestureDetector(
                  onTap: () => setState(() {
                    _useDefault = false;
                    _value = p;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${p.toStringAsFixed(2)}×',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 13,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.inactiveLine,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Fine-tune slider
            Opacity(
              opacity: _useDefault ? 0.3 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fine-tune',
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 11,
                          color: AppColors.sectionHeader,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${_value.toStringAsFixed(2)}×',
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: AppColors.sliderActive,
                      inactiveTrackColor: AppColors.sliderInactive,
                      thumbColor: AppColors.sliderActive,
                      overlayColor:
                          AppColors.sliderActive.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _value.clamp(0.1, 3.0),
                      min: 0.1,
                      max: 3.0,
                      divisions: 29,
                      onChanged: _useDefault
                          ? null
                          : (v) => setState(() => _value = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.sectionHeader)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _SpeedResult(_useDefault ? null : _value),
          ),
          child: const Text('Save',
              style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}

// ── Library picker dialog ─────────────────────────────────────────────────────

class _LibraryPickerDialog extends StatefulWidget {
  final List<({String title, String path})> songs;

  const _LibraryPickerDialog({required this.songs});

  @override
  State<_LibraryPickerDialog> createState() => _LibraryPickerDialogState();
}

class _LibraryPickerDialogState extends State<_LibraryPickerDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.songs
        .where((s) => s.title.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Add Song from Library',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.activeLine,
          fontSize: 15,
        ),
      ),
      content: SizedBox(
        width: 320,
        height: 380,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: AppColors.activeLine,
              ),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  color: AppColors.dimmedLine,
                ),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 18, color: AppColors.dimmedLine),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.songs.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs in your library yet.\nUse "Import File" to add lyrics.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          color: AppColors.sectionHeader,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              color: AppColors.sectionHeader,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final song = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                song.title,
                                style: const TextStyle(
                                  fontFamily: AppTextStyles.fontFamily,
                                  color: AppColors.activeLine,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              onTap: () => Navigator.pop(context, song),
                            );
                          },
                        ),
            ),
          ],
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

// ── Colour picker dialog ──────────────────────────────────────────────────────

class _ColorPickerDialog extends StatelessWidget {
  final int current;

  const _ColorPickerDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Choose a colour',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          color: AppColors.activeLine,
          fontSize: 15,
        ),
      ),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _palette.map((value) {
          final isCurrent = value == current;
          return GestureDetector(
            onTap: () => Navigator.pop(context, value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  width: isCurrent ? 2.5 : 1.5,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: Color(value).withValues(alpha: 0.6),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: isCurrent
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
            ),
          );
        }).toList(),
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
