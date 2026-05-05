import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/file_service.dart';
import '../services/script_parser.dart';
import '../utils/constants.dart';

class HomeView extends StatefulWidget {
  final void Function(Script script) onOpenScript;

  const HomeView({super.key, required this.onOpenScript});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final FileService _fileService = FileService();
  bool _loading = false;

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

  Future<void> _openFromFile() async {
    setState(() => _loading = true);
    final result = await _fileService.openFile();
    setState(() => _loading = false);
    if (result == null) return;
    final script = ScriptParser.parse(result.content, title: result.title);
    widget.onOpenScript(script);
  }

  void _openExample() {
    final script = ScriptParser.parse(_exampleScript, title: 'Example Song');
    widget.onOpenScript(script);
  }

  Future<void> _openAutosave() async {
    final content = await _fileService.loadAutosave();
    if (content == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No autosave found.'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
      return;
    }
    final script = ScriptParser.parse(content, title: 'Autosaved Script');
    widget.onOpenScript(script);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 64),
            _buildMenu(),
            const SizedBox(height: 48),
            _buildKeyboardHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        const Icon(
          Icons.mic_rounded,
          size: 56,
          color: AppColors.accent,
        ),
        const SizedBox(height: 16),
        const Text(
          'MUSIC TELEPROMPTER',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.activeLine,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Beat-synced lyrics for live performance',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            color: AppColors.sectionHeader,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    return Column(
      children: [
        _menuButton(
          icon: Icons.edit_note_rounded,
          label: 'New Script',
          subtitle: 'Start with an empty editor',
          onTap: () => widget.onOpenScript(Script.empty()),
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        _menuButton(
          icon: Icons.folder_open_rounded,
          label: 'Open File',
          subtitle: 'Load a .txt or .lrc file',
          onTap: _loading ? null : _openFromFile,
        ),
        const SizedBox(height: 12),
        _menuButton(
          icon: Icons.restore_rounded,
          label: 'Open Last Session',
          subtitle: 'Continue from autosave',
          onTap: _openAutosave,
        ),
        const SizedBox(height: 12),
        _menuButton(
          icon: Icons.music_note_rounded,
          label: 'Load Example',
          subtitle: 'Try with a sample song',
          onTap: _openExample,
        ),
      ],
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: 340,
      child: Material(
        color: isPrimary ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.surfaceElevated,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isPrimary ? AppColors.accent : AppColors.inactiveLine,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 14,
                        color: isPrimary ? AppColors.accent : AppColors.activeLine,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 11,
                        color: AppColors.sectionHeader,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardHint() {
    return const Text(
      'SPACE  play/pause  ·  ↑↓  speed  ·  ←→  jump section  ·  F  fullscreen  ·  M  mirror',
      style: TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontSize: 11,
        color: AppColors.dimmedLine,
        letterSpacing: 0.5,
      ),
    );
  }
}
