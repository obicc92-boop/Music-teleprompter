import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../engine/sync_engine.dart';
import '../utils/constants.dart';

class SettingsView extends StatefulWidget {
  final AppSettings settings;
  final SyncEngine syncEngine;
  final void Function(AppSettings) onChanged;
  final VoidCallback onClose;

  const SettingsView({
    super.key,
    required this.settings,
    required this.syncEngine,
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
    if (updated.useManualBpm) {
      widget.syncEngine.setManualBpm(updated.manualBpmOverride);
    }
    widget.syncEngine.setUseManualBpm(updated.useManualBpm);
    widget.syncEngine.setAutoScrollOnVoice(updated.autoScrollOnVoice);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 20),
            _section('DISPLAY'),
            _fontSizeRow(),
            const SizedBox(height: 16),
            _section('SCROLL'),
            _speedRow(),
            _toggleRow(
              'Auto-scroll on voice',
              _settings.autoScrollOnVoice,
              (v) => _update(_settings.copyWith(autoScrollOnVoice: v)),
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
            _toggleRow(
              'Mirror mode',
              _settings.mirrorMode,
              (v) => _update(_settings.copyWith(mirrorMode: v)),
            ),
            const SizedBox(height: 24),
            _closeButton(),
          ],
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
