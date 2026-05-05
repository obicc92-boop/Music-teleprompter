import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/file_service.dart';
import '../services/script_parser.dart';
import '../utils/constants.dart';

class HomeView extends StatefulWidget {
  final void Function(Script script) onOpenScript;
  final void Function(Script script) onLaunchScript;

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
  List<({String title, String path, DateTime modified})> _library = [];
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

  Future<void> _importFile() async {
    setState(() => _importing = true);
    final result = await _fileService.openFile();
    setState(() => _importing = false);
    if (result == null) return;
    await _fileService.saveToLibrary(result.content, result.title);
    await _loadLibrary();
    if (!mounted) return;
    final script = ScriptParser.parse(result.content, title: result.title);
    widget.onOpenScript(script);
  }

  Future<void> _openEntry(String path, String title) async {
    final content = await _fileService.readSavedScript(path);
    if (content == null || !mounted) return;
    widget.onOpenScript(ScriptParser.parse(content, title: title));
  }

  Future<void> _launchEntry(String path, String title) async {
    final content = await _fileService.readSavedScript(path);
    if (content == null || !mounted) return;
    final script = ScriptParser.parse(content, title: title);
    if (script.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Script is empty — open it to add lyrics first.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    widget.onLaunchScript(script);
  }

  Future<void> _deleteEntry(String path) async {
    await _fileService.deleteFromLibrary(path);
    await _loadLibrary();
  }

  void _loadExample() {
    final script = ScriptParser.parse(_exampleScript, title: 'Example Song');
    widget.onOpenScript(script);
  }

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
            onTap: _loadExample,
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
              Icon(
                icon,
                size: 15,
                color: isPrimary ? Colors.black : AppColors.sectionHeader,
              ),
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
              Tooltip(
                message: 'Refresh list',
                child: InkWell(
                  onTap: _loadLibrary,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: AppColors.dimmedLine,
                    ),
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
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (_library.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.queue_music_rounded,
              size: 52,
              color: AppColors.dimmedLine,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your setlist is empty',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 16,
                color: AppColors.inactiveLine,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click "Import File" to add .txt or .lrc lyric files',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: AppColors.dimmedLine,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      itemCount: _library.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildItem(_library[i]),
    );
  }

  Widget _buildItem(({String title, String path, DateTime modified}) entry) {
    return Dismissible(
      key: ValueKey(entry.path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Delete script?',
              style: TextStyle(color: AppColors.activeLine, fontSize: 16),
            ),
            content: Text(
              '"${entry.title}" will be removed from your setlist.',
              style: const TextStyle(color: AppColors.sectionHeader, fontSize: 13),
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
        ) ?? false;
      },
      onDismissed: (_) => _deleteEntry(entry.path),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _openEntry(entry.path, entry.title),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceElevated),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                Tooltip(
                  message: 'Open in editor',
                  child: InkWell(
                    onTap: () => _openEntry(entry.path, entry.title),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 17,
                        color: AppColors.sectionHeader,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _launchButton(() => _launchEntry(entry.path, entry.title)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _launchButton(VoidCallback onTap) {
    return Tooltip(
      message: 'Launch teleprompter directly',
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
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
