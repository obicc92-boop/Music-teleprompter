import 'package:flutter/material.dart';
import '../engine/voice_profiler.dart';
import '../utils/constants.dart';

class EnrollmentDialog extends StatefulWidget {
  final VoiceProfiler profiler;
  final VoidCallback onProfileBuilt;

  const EnrollmentDialog({
    super.key,
    required this.profiler,
    required this.onProfileBuilt,
  });

  @override
  State<EnrollmentDialog> createState() => _EnrollmentDialogState();
}

class _EnrollmentDialogState extends State<EnrollmentDialog> {
  double _recordingProgress = 0.0;
  bool _isRecording = false;
  String? _errorMsg;

  Future<void> _recordSample() async {
    if (_isRecording) return;
    if (widget.profiler.enrolledCount >= VoiceProfiler.totalEnrollmentSamples) return;

    setState(() {
      _isRecording = true;
      _recordingProgress = 0.0;
      _errorMsg = null;
    });

    final success = await widget.profiler.enrollSample(
      onProgress: (p) {
        if (mounted) setState(() => _recordingProgress = p);
      },
    );

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingProgress = success ? 1.0 : 0.0;
        if (!success) _errorMsg = 'Recording failed — check microphone permissions.';
      });
    }
  }

  void _buildAndClose() {
    widget.profiler.buildProfile();
    widget.onProfileBuilt();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.profiler,
      builder: (context, _) {
        final count = widget.profiler.enrolledCount;
        const total = VoiceProfiler.totalEnrollmentSamples;
        final canBuild = count >= 3;
        final complete = count >= total;

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 10),
                const Text(
                  'Sing a phrase 5 times so the app learns your voice.\n'
                  'Do this backstage before the show for best results.',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 12,
                    color: AppColors.sectionHeader,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _sampleDots(count, total),
                const SizedBox(height: 16),
                if (_isRecording) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _recordingProgress,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Recording… sing now',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_errorMsg != null) ...[
                  Text(
                    _errorMsg!,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 12,
                      color: Color(0xFFEF5350),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (!complete)
                      Expanded(
                        child: _actionButton(
                          label: _isRecording
                              ? 'Recording…'
                              : 'Record Sample ${count + 1}',
                          icon: Icons.mic_rounded,
                          color: AppColors.accent,
                          onTap: _isRecording ? null : _recordSample,
                        ),
                      ),
                    if (canBuild) ...[
                      if (!complete) const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          label: 'Build Profile',
                          icon: Icons.fingerprint,
                          color: const Color(0xFF66BB6A),
                          onTap: _buildAndClose,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 12,
                        color: AppColors.sectionHeader,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(
          Icons.record_voice_over_rounded,
          color: AppColors.accent,
          size: 18,
        ),
        const SizedBox(width: 8),
        const Text(
          'VOICE FINGERPRINT',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 13,
            color: AppColors.activeLine,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sampleDots(int count, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < count;
        final active = _isRecording && i == count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppColors.accent
                  : active
                      ? AppColors.accent.withValues(alpha: 0.3)
                      : AppColors.surfaceElevated,
              border: Border.all(
                color: done || active
                    ? AppColors.accent
                    : AppColors.sectionHeader.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.black)
                : active
                    ? const Icon(
                        Icons.mic,
                        size: 16,
                        color: AppColors.accent,
                      )
                    : Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 11,
                            color: AppColors.sectionHeader,
                          ),
                        ),
                      ),
          ),
        );
      }),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
