import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/script.dart';
import '../models/setlist_models.dart';
import '../services/backup_service.dart'
    show BackupFile, BackupService, backupLocationLabel;
import '../services/file_service.dart';
import '../services/lrclib_service.dart';
import '../services/script_parser.dart';
import '../services/setlist_export_service.dart';
import '../services/setlist_service.dart';
import '../services/song_lrc_content_store.dart';
import '../services/song_settings_store.dart';
import '../utils/constants.dart';
import '../widgets/lrc_search_dialog.dart';

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
  final void Function(Script, List<SetlistEntry>, int) onOpenScriptWithSetlist;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenShortcuts;

  /// A restored backup can bring new default settings.
  final VoidCallback onSettingsRestored;

  const HomeView({
    super.key,
    required this.onOpenScript,
    required this.onLaunchScript,
    required this.onOpenScriptWithSetlist,
    required this.onOpenSettings,
    required this.onOpenShortcuts,
    required this.onSettingsRestored,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _setlistService = SetlistService();
  final _fileService = FileService();
  final _backupService = BackupService();

  List<Setlist> _setlists = [];
  int _activeTab = 0;
  bool _loading = true;
  bool _importing = false;
  Map<String, double> _songSpeeds = {}; // song title → its own speed
  Set<String> _timedSongs = {}; // titles of songs that follow their timing
  Map<String, String> _songDetails = {}; // song file → "70 lines · 9 sections"
  String? _selectedId; // chosen with a click or ↑/↓; Enter launches it
  final _listFocus = FocusNode(debugLabel: 'SetlistKeys');

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
    _listFocus.dispose();
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
      _loadSongInfo();
    }
  }

  // Speed, timing and size shown on each row
  Future<void> _loadSongInfo() async {
    final speeds = <String, double>{};
    final timed = <String>{};
    final details = Map<String, String>.of(_songDetails);
    for (final setlist in _setlists) {
      for (final item in setlist.items.where((i) => i.isSong)) {
        final speed = (await SongSettingsStore.getSettings(
          item.title,
        )).scrollSpeedMultiplier;
        if (speed != null) speeds[item.title] = speed;
        if (await SongLrcContentStore.getContent(item.title) != null) {
          timed.add(item.title);
        }
        if (!details.containsKey(item.path)) {
          final content = await _fileService.readSavedScript(item.path);
          if (content == null) {
            details[item.path] = 'Lyrics file not found';
          } else {
            final script = ScriptParser.parse(content);
            final lines = script.totalLines;
            final sections = script.sections.length;
            details[item.path] =
                '$lines line${lines == 1 ? '' : 's'} · '
                '$sections section${sections == 1 ? '' : 's'}';
          }
        }
      }
    }
    if (mounted) {
      setState(() {
        _songSpeeds = speeds;
        _timedSongs = timed;
        _songDetails = details;
      });
    }
  }

  // ── Import from LRCLIB ────────────────────────────────────────────────────

  Future<void> _importFromLrclib() async {
    if (_active == null) return;
    final picked = await showDialog<Object>(
      context: context,
      builder: (_) => LrcSearchDialog(songTitle: ''),
    );
    if (picked == null || picked is! LrclibResult || !mounted) return;

    final result = picked;

    // Derive plain-text script content: use plainLyrics, or strip timestamps
    final String rawLyrics;
    if (result.plainLyrics != null && result.plainLyrics!.trim().isNotEmpty) {
      rawLyrics = result.plainLyrics!;
    } else {
      // Strip LRC timestamps to get readable text
      final tsRe = RegExp(r'\[\d+:\d+(?:\.\d+)?\]');
      rawLyrics = result.syncedLyrics!
          .split('\n')
          .map((l) => l.replaceAll(tsRe, '').trim())
          .where((l) => l.isNotEmpty)
          .join('\n');
    }

    // Build title: "Track Name — Artist"
    final title = result.artistName.isNotEmpty
        ? '${result.trackName} — ${result.artistName}'
        : result.trackName;

    // Save script to library and get its path
    final path = await _fileService.saveToLibrary(rawLyrics, title);

    // Store the synced LRC content for beat-sync scrolling
    if (result.hasSyncedLyrics) {
      await SongLrcContentStore.saveContent(title, result.syncedLyrics!);
    }

    // Add as a new song in the active setlist
    final item = SetlistItem.song(path: path, title: title);
    _updateActiveItems([..._active!.items, item]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$title" added to setlist${result.hasSyncedLyrics ? ' with synced lyrics' : ''}',
            style: const TextStyle(fontFamily: AppTextStyles.ui, fontSize: 13),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _save() => _setlistService.save(_setlists);

  void _updateActiveItems(List<SetlistItem> items) {
    if (_active == null) return;
    setState(() => _setlists[_activeTab] = _active!.copyWith(items: items));
    _save();
    _loadSongInfo(); // an added song may already have its own speed
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
    final name = await _promptText(
      'Rename Setlist',
      'Setlist name',
      _active!.name,
    );
    if (name == null || name.trim().isEmpty) return;
    setState(
      () => _setlists[_activeTab] = _active!.copyWith(name: name.trim()),
    );
    _save();
  }

  Future<void> _exportSetlist() async {
    if (_active == null) return;
    final path = await SetlistExportService.exportHtml(_active!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null
              ? 'Opened in browser — use File › Print › Save as PDF'
              : 'Export failed',
          style: const TextStyle(fontFamily: AppTextStyles.ui, fontSize: 13),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _doBackup() async {
    final setlistsJson = _setlists.map((s) => s.toJson()).toList();
    try {
      final path = await _backupService.backup(setlistsJson);
      if (!mounted) return;
      final msg = path != null
          ? 'Backed up everything to ${backupLocationLabel(path)}. '
                'To move your show, restore that file on the other computer.'
          : 'Backup cancelled';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(fontFamily: AppTextStyles.ui, fontSize: 13),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup failed: $e',
            style: const TextStyle(fontFamily: AppTextStyles.ui, fontSize: 13),
          ),
        ),
      );
    }
  }

  // Pick the file first, then show what's in it before anything changes
  Future<void> _doRestore() async {
    final messenger = ScaffoldMessenger.of(context);
    BackupFile? backup;
    try {
      backup = await _backupService.pickBackup();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("That file isn't a Music Teleprompter backup."),
        ),
      );
      return;
    }
    if (backup == null || !mounted) return;

    final created = backup.createdAt;
    final from = created == null
        ? 'This backup'
        : 'The backup from ${created.day} ${_monthNames[created.month - 1]} ${created.year}';
    final setlists =
        '${backup.setlistCount} setlist${backup.setlistCount == 1 ? '' : 's'}';
    final songs = '${backup.songCount} song${backup.songCount == 1 ? '' : 's'}';
    final withSettings = backup.hasSettings
        ? 'with all their settings'
        : 'without song settings (it was made before backups included them)';

    final confirmed = await _confirm(
      'Restore backup?',
      '$from has $setlists and $songs, $withSettings.\n\n'
          'Your setlists are replaced by the ones in the backup. Its songs and '
          'settings are added or updated — other songs on this computer stay.',
      confirmLabel: 'Restore',
    );
    if (!confirmed || !mounted) return;

    try {
      await _backupService.restore(backup);
      if (!mounted) return;
      await _load();
      widget.onSettingsRestored();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            backup.hasSettings
                ? 'Restored $setlists and $songs, with their settings.'
                : 'Restored $setlists and $songs.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Future<void> _deleteSetlist() async {
    if (_active == null || _setlists.length <= 1) return;
    final ok = await _confirm(
      'Delete "${_active!.name}"?',
      'This setlist will be removed. Songs in your library are not deleted.',
      confirmLabel: 'Delete',
      destructive: true,
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
    try {
      final result = await _fileService.openFile();
      if (result == null || !mounted) return;
      final path = await _fileService.saveToLibrary(
        result.content,
        result.title,
      );
      if (!mounted) return;

      if (_active != null) {
        // Add to current setlist so it shows up as a card
        final item = SetlistItem.song(path: path, title: result.title);
        _updateActiveItems([..._active!.items, item]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${result.title}" imported and added to setlist',
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 13,
              ),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // No setlist yet — open in editor
        widget.onOpenScript(
          ScriptParser.parse(result.content, title: result.title),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import failed: $e',
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 13,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
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

  // Speed belongs to the song, so it applies in every setlist it appears in.
  Future<void> _pickSpeed(SetlistItem item) async {
    final result = await showDialog<_SpeedResult>(
      context: context,
      builder: (_) => _SpeedPickerDialog(current: _songSpeeds[item.title]),
    );
    if (result == null) return; // cancelled
    final song = await SongSettingsStore.getSettings(item.title);
    await SongSettingsStore.saveSettings(
      item.title,
      song.withSpeed(result.speed),
    );
    _loadSongInfo();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  // Removes straight away and offers Undo, instead of asking first
  void _deleteItem(SetlistItem item) {
    final active = _active;
    if (active == null) return;
    final index = active.items.indexWhere((i) => i.id == item.id);
    if (index < 0) return;
    final tab = _activeTab;
    _updateActiveItems([...active.items]..removeAt(index));

    final what = item.isSong ? '“${item.title}”' : 'the section break';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Removed $what from ${active.name}. The song file stays in your library.',
          ),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted || tab >= _setlists.length) return;
              final items = [..._setlists[tab].items]
                ..insert(index.clamp(0, _setlists[tab].items.length), item);
              setState(
                () => _setlists[tab] = _setlists[tab].copyWith(items: items),
              );
              _save();
              _loadSongInfo();
            },
          ),
        ),
      );
  }

  // ── Inline edit ───────────────────────────────────────────────────────────

  void _beginEdit(SetlistItem item) {
    if (_editingId != null) _commitEdit();
    setState(() => _editingId = item.id);
    _editCtrl.text = item.isSong ? item.note : item.text;
    _editCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _editCtrl.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editFocus.requestFocus(),
    );
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
    final updated = item.isSong
        ? item.copyWith(note: value)
        : item.copyWith(text: value);
    setState(() => _editingId = null);
    _replaceItem(updated);
    _listFocus.requestFocus();
  }

  // ── Launch / open editor ──────────────────────────────────────────────────

  Future<void> _launchItem(SetlistItem item) async {
    final content = await _fileService.readSavedScript(item.path);
    if (!mounted) return;
    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found — it may have been moved or deleted.'),
        ),
      );
      return;
    }
    final script = ScriptParser.parse(content, title: item.title);
    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script is empty — open it to add lyrics first.'),
        ),
      );
      return;
    }
    final songs = _active!.items.where((i) => i.isSong).toList();
    final entries = songs.map((i) => (path: i.path, title: i.title)).toList();
    final index = songs.indexWhere((i) => i.id == item.id);
    widget.onLaunchScript(script, entries, index);
  }

  Future<void> _editItem(SetlistItem item) async {
    final content = await _fileService.readSavedScript(item.path);
    if (content == null || !mounted || _active == null) return;
    final script = ScriptParser.parse(content, title: item.title);
    final songs = _active!.items.where((i) => i.isSong).toList();
    final entries = songs.map((i) => (path: i.path, title: i.title)).toList();
    final index = songs.indexWhere((i) => i.id == item.id);
    widget.onOpenScriptWithSetlist(
      script,
      entries,
      index.clamp(0, entries.length - 1),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1000;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(compact: compact),
              Expanded(child: _buildMain(compact: compact)),
            ],
          );
        },
      ),
    );
  }

  // ── Sidebar: every setlist, then app-wide places ─────────────────────────

  Widget _buildSidebar({required bool compact}) {
    return Container(
      width: compact ? 200 : 248,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text('SETLISTS', style: AppTextStyles.eyebrow),
          ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _setlists.length; i++) _setlistTile(i),
                _sidebarTile(
                  icon: Icons.add_rounded,
                  label: 'New setlist',
                  color: AppColors.uiHint,
                  onTap: _addSetlist,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sidebarTile(
            icon: Icons.keyboard_rounded,
            label: compact ? 'Shortcuts' : 'Keyboard shortcuts',
            onTap: widget.onOpenShortcuts,
          ),
          _sidebarTile(
            icon: Icons.tune_rounded,
            label: 'Settings',
            onTap: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _setlistTile(int index) {
    final setlist = _setlists[index];
    final selected = index == _activeTab;
    final songCount = setlist.items.where((i) => i.isSong).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.surfaceSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (_editingId != null) _commitEdit();
            setState(() {
              _activeTab = index;
              _selectedId = null;
            });
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    setlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.uiText,
                    ),
                  ),
                ),
                Text(
                  '$songCount',
                  style: TextStyle(
                    fontFamily: AppTextStyles.mono,
                    fontSize: 12,
                    color: selected ? AppColors.accentText : AppColors.uiMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.uiText,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main: header, song list, key hints ────────────────────────────────────

  Widget _buildMain({required bool compact}) {
    final active = _active;
    final hasItems = active != null && active.items.isNotEmpty;
    final side = compact ? 24.0 : 56.0;
    return Focus(
      focusNode: _listFocus,
      autofocus: true,
      onKeyEvent: _onListKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, compact ? 28 : 40, side, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(active, compact: compact),
            SizedBox(height: compact ? 20 : 28),
            if (hasItems && !compact) _columnLabels(),
            Expanded(child: _buildList(compact: compact)),
            if (hasItems && !compact) _keyHints(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Setlist? active, {required bool compact}) {
    final songs = active?.items.where((i) => i.isSong).toList() ?? const [];
    final timed = songs.where((s) => _timedSongs.contains(s.title)).length;
    final meta = [
      '${songs.length} song${songs.length == 1 ? '' : 's'}',
      if (timed == 1) '1 follows its timing',
      if (timed > 1) '$timed follow their timing',
    ].join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SETLIST', style: AppTextStyles.eyebrow),
              const SizedBox(height: 6),
              Text(
                (active?.name ?? '').toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.display,
                  fontSize: compact ? 34 : 50,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meta,
                style: const TextStyle(fontSize: 14, color: AppColors.uiText),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _setlistMenu(),
        const SizedBox(width: 10),
        _addMenu(compact: compact),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: songs.isEmpty ? null : () => _launchItem(songs.first),
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(compact ? 'Start' : 'Start show'),
        ),
      ],
    );
  }

  // A header button that opens a menu
  Widget _menuButtonFace({
    IconData? icon,
    String? label,
    bool chevron = false,
  }) {
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: label == null ? 13 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color: label == null ? AppColors.uiText : AppColors.textPrimary,
            ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (chevron) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.uiHint,
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<VoidCallback> _menuEntry(
    IconData icon,
    String title,
    VoidCallback action, {
    String? subtitle,
    bool danger = false,
    bool enabled = true,
  }) {
    final color = !enabled
        ? AppColors.uiMuted
        : danger
        ? AppColors.danger
        : AppColors.textPrimary;
    return PopupMenuItem<VoidCallback>(
      value: action,
      enabled: enabled,
      height: subtitle == null ? 40 : 52,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: danger ? AppColors.danger : AppColors.uiText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.uiHint,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addMenu({required bool compact}) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Add songs and breaks',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 300),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        _menuEntry(
          Icons.library_music_rounded,
          'Song from library',
          _showAddSong,
          subtitle: 'Pick a song you already have',
        ),
        _menuEntry(
          Icons.search_rounded,
          'Find lyrics online',
          _importFromLrclib,
          subtitle: 'Comes with timing when there is one',
        ),
        _menuEntry(
          Icons.edit_note_rounded,
          'Write new lyrics',
          () => widget.onOpenScript(Script.empty()),
        ),
        _menuEntry(
          Icons.file_download_rounded,
          'Import a file',
          _importFile,
          subtitle: '.txt or .lrc',
          enabled: !_importing,
        ),
        const PopupMenuDivider(height: 9),
        _menuEntry(
          Icons.horizontal_rule_rounded,
          'Section break',
          _addSeparator,
          subtitle: 'Set break, band intro, stage note',
        ),
      ],
      child: _menuButtonFace(
        icon: Icons.add_rounded,
        label: 'Add',
        chevron: !compact,
      ),
    );
  }

  Widget _setlistMenu() {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Setlist options',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 260),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        _menuEntry(Icons.edit_rounded, 'Rename', _renameSetlist),
        _menuEntry(Icons.print_rounded, 'Print or save as PDF', _exportSetlist),
        const PopupMenuDivider(height: 9),
        _menuEntry(
          Icons.cloud_upload_outlined,
          'Back up everything',
          _doBackup,
          subtitle: 'Setlists, songs and all their settings',
        ),
        _menuEntry(
          Icons.cloud_download_outlined,
          'Restore a backup',
          _doRestore,
          subtitle: 'Also moves your show to another computer',
        ),
        const PopupMenuDivider(height: 9),
        _menuEntry(
          Icons.delete_outline_rounded,
          'Delete setlist',
          _deleteSetlist,
          danger: true,
          enabled: _setlists.length > 1,
        ),
      ],
      child: _menuButtonFace(icon: Icons.more_horiz_rounded),
    );
  }

  Widget _columnLabels() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: AppColors.uiMuted,
    );
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: const Row(
        children: [
          SizedBox(width: _SongRow.gripWidth),
          SizedBox(
            width: _SongRow.numberWidth,
            child: Text('#', style: style),
          ),
          Expanded(child: Text('SONG', style: style)),
          SizedBox(
            width: _SongRow.playbackWidth,
            child: Text('PLAYBACK', style: style),
          ),
          SizedBox(width: _SongRow.actionsWidth),
        ],
      ),
    );
  }

  Widget _keyHints() {
    Widget key(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTextStyles.mono,
          fontSize: 11,
          color: AppColors.uiText,
        ),
      ),
    );
    const hint = TextStyle(fontSize: 12, color: AppColors.uiMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          key('↑↓'),
          const SizedBox(width: 8),
          const Text('choose a song', style: hint),
          const SizedBox(width: 20),
          key('Enter'),
          const SizedBox(width: 8),
          const Text('launch it — or double-click its name', style: hint),
        ],
      ),
    );
  }

  Widget _buildList({required bool compact}) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }
    final active = _active;
    if (active == null || active.items.isEmpty) return _buildEmptyState();

    final numbers = <String, int>{};
    for (final item in active.items.where((i) => i.isSong)) {
      numbers[item.id] = numbers.length + 1;
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      buildDefaultDragHandles: false,
      itemCount: active.items.length,
      onReorder: _onReorder,
      // The dragged row lifts off the list
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = Curves.easeOut.transform(animation.value);
          return Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSelected,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5 * t),
                    blurRadius: 32 * t,
                    offset: Offset(0, 14 * t),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: child,
      ),
      itemBuilder: (_, i) {
        final item = active.items[i];
        if (!item.isSong) {
          return _BreakRow(
            key: GlobalObjectKey(item.id),
            item: item,
            index: i,
            isEditing: _editingId == item.id,
            editCtrl: _editCtrl,
            editFocus: _editFocus,
            onBeginEdit: () => _beginEdit(item),
            onCommitEdit: _commitEdit,
            onRemove: () => _deleteItem(item),
          );
        }
        final grouped = item.cardPosition > 0.01 && i > 0;
        return _SongRow(
          key: GlobalObjectKey(item.id),
          item: item,
          index: i,
          number: numbers[item.id]!,
          detail: item.note.isNotEmpty ? item.note : _songDetails[item.path],
          speed: _songSpeeds[item.title],
          isTimed: _timedSongs.contains(item.title),
          isGrouped: grouped,
          canGroup: i > 0,
          isSelected: _selectedId == item.id,
          compact: compact,
          isEditingNote: _editingId == item.id,
          editCtrl: _editCtrl,
          editFocus: _editFocus,
          onSelect: () => _select(item),
          onLaunch: () => _launchItem(item),
          onEditLyrics: () => _editItem(item),
          onEditNote: () => _beginEdit(item),
          onCommitNote: _commitEdit,
          onPickSpeed: () => _pickSpeed(item),
          onPickColor: () => _pickColor(item),
          onToggleGroup: () =>
              _replaceItem(item.copyWith(cardPosition: grouped ? 0.0 : 1.0)),
          onRemove: () => _deleteItem(item),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.queue_music_rounded,
                size: 30,
                color: AppColors.accentText,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This setlist is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use Add to pick songs from your library, find lyrics online or import a file.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.uiText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => widget.onOpenScript(
                ScriptParser.parse(_exampleScript, title: 'Example Song'),
              ),
              icon: const Icon(Icons.music_note_rounded, size: 18),
              label: const Text('Try the example song'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selection and keys ────────────────────────────────────────────────────

  void _select(SetlistItem item) {
    setState(() => _selectedId = item.id);
    if (_editingId == null) _listFocus.requestFocus();
  }

  // ↑/↓ choose a song, Enter launches it
  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final songs = _active?.items.where((i) => i.isSong).toList() ?? const [];
    if (songs.isEmpty) return KeyEventResult.ignored;
    final current = songs.indexWhere((s) => s.id == _selectedId);
    final key = event.logicalKey;

    int? next;
    if (key == LogicalKeyboardKey.arrowDown) {
      next = current < 0 ? 0 : (current + 1).clamp(0, songs.length - 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      next = current <= 0 ? 0 : current - 1;
    } else if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        current >= 0) {
      _launchItem(songs[current]);
      return KeyEventResult.handled;
    }
    if (next == null) return KeyEventResult.ignored;

    final song = songs[next];
    setState(() => _selectedId = song.id);
    final rowContext = GlobalObjectKey(song.id).currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 160),
        alignmentPolicy: key == LogicalKeyboardKey.arrowDown
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
    return KeyEventResult.handled;
  }

  // ── Utility dialogs ───────────────────────────────────────────────────────

  Future<String?> _promptText(String title, String hint, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 400, child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: destructive
                ? ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.onAccent,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Song row ─────────────────────────────────────────────────────────────────

class _SongRow extends StatefulWidget {
  static const gripWidth = 36.0;
  static const numberWidth = 44.0;
  static const playbackWidth = 150.0;
  static const actionsWidth = 136.0;

  final SetlistItem item;
  final int index;
  final int number;
  final String? detail; // the note, or lines and sections
  final double? speed; // the song's own speed, null = default
  final bool isTimed; // follows its timing, so speed doesn't apply
  final bool isGrouped; // runs on from the song above (medley, segue)
  final bool canGroup;
  final bool isSelected;
  final bool compact;
  final bool isEditingNote;
  final TextEditingController editCtrl;
  final FocusNode editFocus;
  final VoidCallback onSelect;
  final VoidCallback onLaunch;
  final VoidCallback onEditLyrics;
  final VoidCallback onEditNote;
  final VoidCallback onCommitNote;
  final VoidCallback onPickSpeed;
  final VoidCallback onPickColor;
  final VoidCallback onToggleGroup;
  final VoidCallback onRemove;

  const _SongRow({
    super.key,
    required this.item,
    required this.index,
    required this.number,
    required this.detail,
    required this.speed,
    required this.isTimed,
    required this.isGrouped,
    required this.canGroup,
    required this.isSelected,
    required this.compact,
    required this.isEditingNote,
    required this.editCtrl,
    required this.editFocus,
    required this.onSelect,
    required this.onLaunch,
    required this.onEditLyrics,
    required this.onEditNote,
    required this.onCommitNote,
    required this.onPickSpeed,
    required this.onPickColor,
    required this.onToggleGroup,
    required this.onRemove,
  });

  @override
  State<_SongRow> createState() => _SongRowState();
}

class _SongRowState extends State<_SongRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final lit = _hovered || widget.isSelected;
    final dotColor = item.colorValue == 0xFF555555
        ? AppColors.uiMuted
        : Color(item.colorValue);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        // Selecting on pointer-down feels instant; launching needs a double-click
        onPointerDown: (_) => widget.onSelect(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 72,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surfaceSelected
                : _hovered
                ? AppColors.surfaceHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: widget.index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: SizedBox(
                    width: _SongRow.gripWidth,
                    height: 72,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: lit ? 1 : 0,
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: AppColors.uiHint,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _SongRow.numberWidth,
                child: Text(
                  widget.number.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: AppTextStyles.mono,
                    fontSize: 14,
                    color: lit ? AppColors.accentText : AppColors.uiMuted,
                  ),
                ),
              ),
              if (widget.isGrouped)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Runs on from the song above',
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 18,
                      color: AppColors.uiMuted,
                    ),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _titleAndDetail()),
              SizedBox(
                width: widget.compact ? 44 : _SongRow.playbackWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _playback(),
                ),
              ),
              SizedBox(
                width: widget.compact ? 92 : _SongRow.actionsWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.compact)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: _hovered ? 1 : 0,
                        child: IconButton(
                          tooltip: 'Edit lyrics',
                          onPressed: widget.onEditLyrics,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          color: AppColors.uiText,
                        ),
                      ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: lit ? 1 : 0.45,
                      child: _rowMenu(),
                    ),
                    const SizedBox(width: 4),
                    _playButton(lit),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleAndDetail() {
    final item = widget.item;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Double-clicking the name launches; the buttons stay single-click
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onLaunch,
          child: Tooltip(
            message: '${item.title}\nDouble-click to launch',
            waitDuration: const Duration(milliseconds: 700),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 17,
          child: widget.isEditingNote
              ? TextField(
                  controller: widget.editCtrl,
                  focusNode: widget.editFocus,
                  style: const TextStyle(fontSize: 12, color: AppColors.uiText),
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Add a note — key, capo, who starts…',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.uiMuted,
                    ),
                  ),
                  onSubmitted: (_) => widget.onCommitNote(),
                )
              : Text(
                  widget.detail ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: item.note.isNotEmpty
                        ? AppColors.uiText
                        : AppColors.uiHint,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _playback() {
    if (widget.isTimed) {
      return Tooltip(
        message:
            'Follows its timing — record or remove it from ••• while the song is open',
        child: Container(
          height: 26,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 10),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 14,
                color: AppColors.accentText,
              ),
              if (!widget.compact) ...[
                const SizedBox(width: 6),
                const Text(
                  'Timed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentText,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final speed = widget.speed;
    return Tooltip(
      message: speed == null
          ? 'Default speed — click to give this song its own'
          : 'Speed ${ScrollConstants.speedLabel(speed)} — click to change',
      child: InkWell(
        onTap: widget.onPickSpeed,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: speed == null
              ? null
              : BoxDecoration(
                  color: AppColors.surfaceSelected,
                  borderRadius: BorderRadius.circular(13),
                ),
          alignment: Alignment.center,
          child: widget.compact && speed == null
              ? const Icon(
                  Icons.speed_rounded,
                  size: 16,
                  color: AppColors.uiMuted,
                )
              : Text(
                  speed == null
                      ? 'Default speed'
                      : ScrollConstants.speedLabel(speed),
                  style: TextStyle(
                    fontFamily: speed == null ? null : AppTextStyles.mono,
                    fontSize: 12,
                    color: speed == null
                        ? AppColors.uiMuted
                        : AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _rowMenu() {
    final item = widget.item;
    PopupMenuItem<VoidCallback> entry(
      IconData icon,
      String label,
      VoidCallback action, {
      bool danger = false,
      bool enabled = true,
    }) {
      return PopupMenuItem<VoidCallback>(
        value: action,
        enabled: enabled,
        height: 40,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: danger
                  ? AppColors.danger
                  : enabled
                  ? AppColors.uiText
                  : AppColors.uiMuted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: danger
                    ? AppColors.danger
                    : enabled
                    ? AppColors.textPrimary
                    : AppColors.uiMuted,
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<VoidCallback>(
      tooltip: 'Song options',
      position: PopupMenuPosition.under,
      onSelected: (action) => action(),
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: AppColors.uiText,
      ),
      itemBuilder: (_) => [
        entry(Icons.play_arrow_rounded, 'Launch', widget.onLaunch),
        entry(Icons.edit_rounded, 'Edit lyrics', widget.onEditLyrics),
        entry(
          Icons.sticky_note_2_outlined,
          item.note.isEmpty ? 'Add a note' : 'Edit note',
          widget.onEditNote,
        ),
        const PopupMenuDivider(height: 9),
        entry(
          Icons.speed_rounded,
          'Speed…',
          widget.onPickSpeed,
          enabled: !widget.isTimed,
        ),
        entry(Icons.palette_outlined, 'Colour…', widget.onPickColor),
        entry(
          Icons.subdirectory_arrow_right_rounded,
          widget.isGrouped
              ? 'Ungroup from the song above'
              : 'Group with the song above',
          widget.onToggleGroup,
          enabled: widget.canGroup,
        ),
        const PopupMenuDivider(height: 9),
        entry(
          Icons.remove_circle_outline_rounded,
          'Remove from setlist',
          widget.onRemove,
          danger: true,
        ),
      ],
    );
  }

  Widget _playButton(bool lit) {
    return Tooltip(
      message: 'Launch',
      child: Material(
        color: lit ? AppColors.accent : AppColors.surfaceElevated,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onLaunch,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.play_arrow_rounded,
              size: 22,
              color: lit ? AppColors.onAccent : AppColors.uiText,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section break row ────────────────────────────────────────────────────────

class _BreakRow extends StatefulWidget {
  final SetlistItem item;
  final int index;
  final bool isEditing;
  final TextEditingController editCtrl;
  final FocusNode editFocus;
  final VoidCallback onBeginEdit;
  final VoidCallback onCommitEdit;
  final VoidCallback onRemove;

  const _BreakRow({
    super.key,
    required this.item,
    required this.index,
    required this.isEditing,
    required this.editCtrl,
    required this.editFocus,
    required this.onBeginEdit,
    required this.onCommitEdit,
    required this.onRemove,
  });

  @override
  State<_BreakRow> createState() => _BreakRowState();
}

class _BreakRowState extends State<_BreakRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.item.text.trim();
    const labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: AppColors.uiHint,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox(
                  width: _SongRow.gripWidth,
                  height: 52,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _hovered ? 1 : 0,
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      size: 20,
                      color: AppColors.uiHint,
                    ),
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider()),
            const SizedBox(width: 16),
            widget.isEditing
                ? SizedBox(
                    width: 280,
                    child: TextField(
                      controller: widget.editCtrl,
                      focusNode: widget.editFocus,
                      textAlign: TextAlign.center,
                      style: labelStyle.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration.collapsed(
                        hintText: 'SET BREAK, BAND INTRO…',
                        hintStyle: labelStyle.copyWith(
                          color: AppColors.uiMuted,
                        ),
                      ),
                      onSubmitted: (_) => widget.onCommitEdit(),
                    ),
                  )
                : GestureDetector(
                    onTap: widget.onBeginEdit,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.text,
                      child: Text(
                        text.isEmpty ? 'SECTION BREAK' : text.toUpperCase(),
                        style: text.isEmpty
                            ? labelStyle.copyWith(color: AppColors.uiMuted)
                            : labelStyle,
                      ),
                    ),
                  ),
            const SizedBox(width: 16),
            const Expanded(child: Divider()),
            SizedBox(
              width: 48,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hovered ? 1 : 0,
                child: IconButton(
                  tooltip: 'Remove break',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: AppColors.uiHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      title: const Text('Song speed'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto toggle
            GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                          : AppColors.surfaceSelected,
                      border: Border.all(
                        color: _useDefault
                            ? AppColors.accent
                            : AppColors.uiHint,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Use the default speed',
                    style: TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
                final isSelected = !_useDefault && (_value - p).abs() < 0.01;
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _useDefault = false;
                      _value = p;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 64,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentSoft
                            : AppColors.surfaceSelected,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        ScrollConstants.speedLabel(p),
                        style: TextStyle(
                          fontFamily: AppTextStyles.mono,
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.accentText
                              : AppColors.uiText,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Fine-tune slider
            Opacity(
              opacity: _useDefault ? 0.3 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('FINE-TUNE', style: AppTextStyles.eyebrow),
                      Text(
                        ScrollConstants.speedLabel(_value),
                        style: const TextStyle(
                          fontFamily: AppTextStyles.mono,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentText,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      tickMarkShape: SliderTickMarkShape.noTickMark,
                    ),
                    child: Slider(
                      value: _value.clamp(
                        ScrollConstants.minSpeedMultiplier,
                        ScrollConstants.maxSpeedMultiplier,
                      ),
                      min: ScrollConstants.minSpeedMultiplier,
                      max: ScrollConstants.maxSpeedMultiplier,
                      divisions:
                          ((ScrollConstants.maxSpeedMultiplier -
                                      ScrollConstants.minSpeedMultiplier) /
                                  ScrollConstants.speedStep)
                              .round(),
                      onChanged: _useDefault
                          ? null
                          : (v) => setState(
                              () => _value = (v * 100).round() / 100,
                            ),
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, _SpeedResult(_useDefault ? null : _value)),
          child: const Text('Save'),
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
      title: const Text('Add a song from your library'),
      content: SizedBox(
        width: 320,
        height: 380,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search your library',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.uiHint,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceSelected,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.songs.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs in your library yet.\nUse Add, then Import a file or Write new lyrics.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTextStyles.ui,
                          color: AppColors.uiHint,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matches',
                        style: TextStyle(
                          fontFamily: AppTextStyles.ui,
                          color: AppColors.uiHint,
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text(
                            song.title,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.ui,
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: AppColors.accentText,
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
          child: const Text('Cancel'),
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
      title: const Text('Choose a colour'),
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
                        ),
                      ]
                    : null,
              ),
              child: isCurrent
                  ? const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
          );
        }).toList(),
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
