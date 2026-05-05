import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/file_service.dart';
import '../services/script_parser.dart';
import '../utils/constants.dart';

// Predefined accent colours for setlist cards
const _palette = [
  0xFF555555, // grey  (default)
  0xFFFF6B35, // orange (app accent)
  0xFF4FC3F7, // sky blue
  0xFF66BB6A, // green
  0xFFAB47BC, // purple
  0xFFEF5350, // red
  0xFFFFD700, // gold
  0xFF26C6DA, // teal
  0xFFEC407A, // pink
  0xFF78909C, // slate
];

typedef SetlistEntry = ({String path, String title});

class HomeView extends StatefulWidget {
  final void Function(Script script) onOpenScript;
  final void Function(
    Script script,
    List<SetlistEntry> setlist,
    int index,
  ) onLaunchScript;

  const HomeView({
    super.key,
    required this.onOpenScript,
    required this.onLaunchScript,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final FileService _fileService = FileService();

  // mutable so reorder / color edits work in-place
  List<({String title, String path, DateTime modified, int colorValue})>
      _library = [];
  bool _loadingLibrary = true;
  bool _importing = false;

  static const String _exampleScript = '''[Intro | 4 bars]

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

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _loadingLibrary = true);
    final entries = await _fileService.listLibrary();
    if (mounted) {
      setState(() {
        _library = entries;
        _loadingLibrary = false;
      });
    }
  }

  Future<void> _saveSetlistMeta() async {
    final filenames = _library.map((e) => e.path.split('/').last).toList();
    final colors = {
      for (final e in _library) e.path.split('/').last: e.colorValue,
    };
    await _fileService.saveSetlistMeta(
      orderedFilenames: filenames,
      colorValues: colors,
    );
  }

  // ── Reorder ──────────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _library.removeAt(oldIndex);
      _library.insert(newIndex, item);
    });
    _saveSetlistMeta();
  }

  // ── Colour ───────────────────────────────────────────────────────────────

  Future<void> _pickColor(int index) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (_) => _ColorPickerDialog(current: _library[index].colorValue),
    );
    if (selected == null) return;
    final e = _library[index];
    setState(() {
      _library[index] = (
        title: e.title,
        path: e.path,
        modified: e.modified,
        colorValue: selected,
      );
    });
    _saveSetlistMeta();
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importFile() async {
    setState(() => _importing = true);
    final result = await _fileService.openFile();
    setState(() => _importing = false);
    if (result == null) return;
    await _fileService.saveToLibrary(result.content, result.title);
    await _loadLibrary();
    if (!mounted) return;
    widget.onOpenScript(ScriptParser.parse(result.content, title: result.title));
  }

  // ── Open / Launch ─────────────────────────────────────────────────────────

  Future<void> _openEntry(int index) async {
    final entry = _library[index];
    final content = await _fileService.readSavedScript(entry.path);
    if (content == null || !mounted) return;
    widget.onOpenScript(ScriptParser.parse(content, title: entry.title));
  }

  Future<void> _launchEntry(int index) async {
    final entry = _library[index];
    final content = await _fileService.readSavedScript(entry.path);
    if (content == null || !mounted) return;
    final script = ScriptParser.parse(content, title: entry.title);
    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Script is empty — open it to add lyrics first.'),
        backgroundColor: AppColors.surface,
      ));
      return;
    }
    final setlist =
        _library.map((e) => (path: e.path, title: e.title)).toList();
    widget.onLaunchScript(script, setlist, index);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteEntry(int index) async {
    final entry = _library[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete script?',
            style: TextStyle(color: AppColors.activeLine, fontSize: 16)),
        content: Text(
          '"${entry.title}" will be removed from your setlist.',
          style: const TextStyle(
              color: AppColors.sectionHeader, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.sectionHeader)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _fileService.deleteFromLibrary(entry.path);
    await _loadLibrary();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          _buildKeyboardHint(),
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
          _headerButton(
            icon: Icons.music_note_rounded,
            label: 'Load Example',
            onTap: () => widget.onOpenScript(
              ScriptParser.parse(_exampleScript, title: 'Example Song'),
            ),
          ),
          const SizedBox(width: 10),
          _headerButton(
            icon: Icons.edit_note_rounded,
            label: 'New Script',
            onTap: () => widget.onOpenScript(Script.empty()),
          ),
          const SizedBox(width: 10),
          _headerButton(
            icon: Icons.file_download_rounded,
            label: _importing ? 'Importing...' : 'Import File',
            onTap: _importing ? null : _importFile,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
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
              Icon(icon, size: 15,
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

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 12),
          child: Row(
            children: [
              const Text(
                'MY SETLIST',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 11,
                  color: AppColors.sectionHeader,
                  letterSpacing: 2,
                ),
              ),
              if (_library.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_library.length}',
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 11,
                      color: AppColors.sectionHeader,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              const Text(
                'Drag to reorder  ·  tap colour dot to customise',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 10,
                  color: AppColors.dimmedLine,
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: 'Refresh',
                child: InkWell(
                  onTap: _loadLibrary,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded,
                        size: 16, color: AppColors.dimmedLine),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loadingLibrary) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }

    if (_library.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.queue_music_rounded,
                size: 52, color: AppColors.dimmedLine),
            SizedBox(height: 16),
            Text(
              'Your setlist is empty',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 16,
                color: AppColors.inactiveLine,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Click "Import File" to add .txt or .lrc lyric files',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: AppColors.dimmedLine,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'or "New Script" to write lyrics from scratch',
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

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      itemCount: _library.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) => Material(
        elevation: 8,
        color: Colors.transparent,
        shadowColor: Colors.black54,
        child: child,
      ),
      itemBuilder: (_, i) => _buildItem(i),
    );
  }

  Widget _buildItem(int index) {
    final entry = _library[index];
    final accent = Color(entry.colorValue);

    return Padding(
      key: ValueKey(entry.path),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _openEntry(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceElevated),
            ),
            child: Row(
              children: [
                // Coloured left accent bar
                Container(
                  width: 4,
                  height: 62,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Colour picker dot
                Tooltip(
                  message: 'Change colour',
                  child: GestureDetector(
                    onTap: () => _pickColor(index),
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
                const SizedBox(width: 14),

                // Song title + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 15,
                          color: AppColors.activeLine,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(entry.modified),
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 11,
                          color: AppColors.sectionHeader,
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit button
                Tooltip(
                  message: 'Open in editor',
                  child: InkWell(
                    onTap: () => _openEntry(index),
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
                    onTap: () => _deleteEntry(index),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 17, color: AppColors.sectionHeader),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Launch button
                _launchButton(() => _launchEntry(index), accent),

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

  Widget _launchButton(VoidCallback onTap, Color accent) {
    return Tooltip(
      message: 'Launch teleprompter',
      child: Material(
        color: accent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _buildKeyboardHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: const Text(
        'SPACE  play/pause  ·  ↑↓  speed  ·  ←→  jump section  ·  F  fullscreen  ·  M  mirror',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 11,
          color: AppColors.dimmedLine,
          letterSpacing: 0.5,
        ),
      ),
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
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: Colors.white)
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
