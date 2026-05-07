import 'package:flutter/material.dart';
import '../engine/sync_engine.dart';
import '../engine/voice_profiler.dart';
import '../services/settings_service.dart';
import '../services/voice_profile_service.dart';
import '../utils/constants.dart';
import '../widgets/enrollment_dialog.dart';

// Re-export so callers don't need a separate import
export '../utils/constants.dart' show DisplayFont;

class SettingsView extends StatefulWidget {
  final AppSettings settings;
  final SyncEngine syncEngine;
  final VoiceProfiler voiceProfiler;
  final VoiceProfileService voiceProfileService;
  final void Function(AppSettings) onChanged;
  final VoidCallback onClose;

  const SettingsView({
    super.key,
    required this.settings,
    required this.syncEngine,
    required this.voiceProfiler,
    required this.voiceProfileService,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late AppSettings _settings;
  late final SettingsService _service;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _service = SettingsService();
  }

  void _update(AppSettings updated) {
    setState(() => _settings = updated);
    _service.save(updated);
    widget.onChanged(updated);
    widget.syncEngine.updateVoiceSensitivity(updated.voiceSensitivity);
    widget.syncEngine.setManualMultiplier(updated.scrollSpeedMultiplier);
    if (updated.useManualBpm) {
      widget.syncEngine.setManualBpm(updated.manualBpmOverride);
    }
    widget.syncEngine.setUseManualBpm(updated.useManualBpm);
    widget.syncEngine.setAutoScrollOnVoice(updated.autoScrollOnVoice);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height - 80;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _header(),
            const SizedBox(height: 20),
            _section('DISPLAY'),
            _fontSizeRow(),
            const SizedBox(height: 12),
            _fontPickerRow(),
            const SizedBox(height: 16),
            _section('SCROLL'),
            _speedRow(),
            _toggleRow(
              'Auto-scroll on voice',
              _settings.autoScrollOnVoice,
              (v) => _update(_settings.copyWith(autoScrollOnVoice: v)),
            ),
            _toggleRow(
              'Auto-advance to next song',
              _settings.autoAdvance,
              (v) => _update(_settings.copyWith(autoAdvance: v)),
            ),
            const SizedBox(height: 16),
            _section('AUDIO'),
            _voiceSensitivityRow(),
            _bpmRow(),
            const SizedBox(height: 16),
            _section('FEATURES'),
            _toggleRow(
              'Karaoke highlight',
              _settings.karaokeMode,
              (v) => _update(_settings.copyWith(karaokeMode: v)),
            ),
            const SizedBox(height: 16),
            _section('FOOT PEDAL'),
            _pedalActionRow(),
            const SizedBox(height: 16),
            _section('VOICE FINGERPRINT'),
            _voiceFingerprintRow(),
            const SizedBox(height: 24),
            _closeButton(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            color: AppColors.activeLine,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.sectionHeader),
          onPressed: widget.onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 10,
          color: AppColors.sectionHeader,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _fontSizeRow() {
    return _sliderRow(
      label: 'Font Size',
      value: _settings.fontSize,
      min: AppDimensions.minFontSize,
      max: AppDimensions.maxFontSize,
      displayValue: '${_settings.fontSize.round()}px',
      onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
    );
  }

  Widget _fontPickerRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 130,
            child: Text(
              'Teleprompter Font',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: AppColors.inactiveLine,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: DisplayFont.options.map((font) {
                final isSelected = _settings.displayFont == font.family;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        _update(_settings.copyWith(displayFont: font.family)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Aa',
                            style: TextStyle(
                              fontFamily: font.family,
                              fontSize: 15,
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.inactiveLine,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            font.label,
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontFamily,
                              fontSize: 9,
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.sectionHeader,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedRow() {
    return _sliderRow(
      label: 'Default Speed',
      value: _settings.scrollSpeedMultiplier,
      min: ScrollConstants.minSpeedMultiplier,
      max: ScrollConstants.maxSpeedMultiplier,
      displayValue: '${_settings.scrollSpeedMultiplier.toStringAsFixed(1)}x',
      onChanged: (v) => _update(_settings.copyWith(scrollSpeedMultiplier: v)),
    );
  }

  Widget _voiceSensitivityRow() {
    return _sliderRow(
      label: 'Voice Sensitivity',
      value: _settings.voiceSensitivity * 1000,
      min: 1,
      max: 100,
      displayValue: _settings.voiceSensitivity.toStringAsFixed(3),
      onChanged: (v) => _update(_settings.copyWith(voiceSensitivity: v / 1000)),
    );
  }

  Widget _bpmRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggleRow(
          'Manual BPM Override',
          _settings.useManualBpm,
          (v) => _update(_settings.copyWith(useManualBpm: v)),
        ),
        if (_settings.useManualBpm)
          _sliderRow(
            label: 'BPM',
            value: _settings.manualBpmOverride,
            min: AudioConstants.minBpm,
            max: AudioConstants.maxBpm,
            displayValue: '${_settings.manualBpmOverride.round()}',
            onChanged: (v) => _update(_settings.copyWith(manualBpmOverride: v)),
          ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required void Function(double) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: AppColors.inactiveLine,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: AppColors.sliderActive,
                inactiveTrackColor: AppColors.sliderInactive,
                thumbColor: AppColors.sliderActive,
                overlayColor: AppColors.sliderActive.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 12,
                color: AppColors.sectionHeader,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, void Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 13,
                color: AppColors.inactiveLine,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.4),
            inactiveThumbColor: AppColors.sectionHeader,
            inactiveTrackColor: AppColors.surfaceElevated,
          ),
        ],
      ),
    );
  }

  Widget _pedalActionRow() {
    const actions = [
      ('nextSection', 'Next Section'),
      ('nextSong', 'Next Song'),
      ('playPause', 'Play / Pause'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: actions.map((entry) {
              final (value, label) = entry;
              final isSelected = _settings.pedalAction == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _update(_settings.copyWith(pedalAction: value)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.accent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 11,
                        color: isSelected ? AppColors.accent : AppColors.inactiveLine,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'PageDown / Enter = forward  ·  PageUp = back\nCompatible with AirTurn, PageFlip, and similar HID pedals',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 10,
              color: AppColors.sectionHeader,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _voiceFingerprintRow() {
    return ListenableBuilder(
      listenable: widget.voiceProfiler,
      builder: (context, _) {
        final profiler = widget.voiceProfiler;
        final hasProfile = profiler.hasProfile;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                hasProfile
                    ? Icons.record_voice_over_rounded
                    : Icons.mic_off_rounded,
                size: 16,
                color: hasProfile ? AppColors.accent : AppColors.sectionHeader,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasProfile
                      ? 'Voice profile active'
                      : 'No profile — scrolls on any sound',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 12,
                    color: hasProfile
                        ? AppColors.activeLine
                        : AppColors.sectionHeader,
                  ),
                ),
              ),
              if (hasProfile)
                _smallButton(
                  label: 'Clear',
                  color: const Color(0xFFEF5350),
                  onTap: () async {
                    profiler.clearProfile();
                    await widget.voiceProfileService.delete();
                  },
                ),
              const SizedBox(width: 8),
              _smallButton(
                label: hasProfile ? 'Re-enroll' : 'Enroll',
                color: AppColors.accent,
                onTap: () => _openEnrollment(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEnrollment() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: EnrollmentDialog(
          profiler: widget.voiceProfiler,
          onProfileBuilt: () async {
            final vector = widget.voiceProfiler.profileVector;
            if (vector != null) {
              await widget.voiceProfileService.save(List<double>.from(vector));
            }
          },
        ),
      ),
    );
  }

  Widget _smallButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 11,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _closeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onClose,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          foregroundColor: AppColors.activeLine,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'CLOSE',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
