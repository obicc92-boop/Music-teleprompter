import 'dart:math' as math;
import '../utils/constants.dart';

class VoiceState {
  final bool isActive;
  final double energy;
  final double smoothedEnergy;
  final double timestamp;

  const VoiceState({
    required this.isActive,
    required this.energy,
    required this.smoothedEnergy,
    required this.timestamp,
  });
}

class VoiceDetectionLayer {
  double sensitivityThreshold;

  double _smoothedEnergy = 0.0;
  bool _isVoiceActive = false;
  double _silenceStartTime = 0.0;
  double _voiceStartTime = 0.0;
  double _audioTime = 0.0;

  // Exponential smoothing constants
  static const double _attackSmoothing = 0.3;
  static const double _releaseSmoothing = 0.05;
  static const double _minVoiceDurationMs = 80.0;
  static const double _minSilenceDurationMs = 300.0;

  VoiceDetectionLayer({
    this.sensitivityThreshold = AudioConstants.voiceEnergyThreshold,
  });

  VoiceState processSamples(List<double> samples, int sampleRate) {
    _audioTime += samples.length / sampleRate;

    final rms = _computeRms(samples);
    final smoothing = rms > _smoothedEnergy ? _attackSmoothing : _releaseSmoothing;
    _smoothedEnergy = _smoothedEnergy * (1.0 - smoothing) + rms * smoothing;

    final rawVoice = _smoothedEnergy > sensitivityThreshold;

    if (rawVoice && !_isVoiceActive) {
      _voiceStartTime = _audioTime;
    } else if (!rawVoice && _isVoiceActive) {
      _silenceStartTime = _audioTime;
    }

    final voiceDuration = (_audioTime - _voiceStartTime) * 1000;
    final silenceDuration = (_audioTime - _silenceStartTime) * 1000;

    if (!_isVoiceActive && rawVoice && voiceDuration > _minVoiceDurationMs) {
      _isVoiceActive = true;
    } else if (_isVoiceActive && !rawVoice && silenceDuration > _minSilenceDurationMs) {
      _isVoiceActive = false;
    }

    return VoiceState(
      isActive: _isVoiceActive,
      energy: rms,
      smoothedEnergy: _smoothedEnergy,
      timestamp: _audioTime,
    );
  }

  bool get isVoiceActive => _isVoiceActive;

  double get smoothedEnergy => _smoothedEnergy;

  double _computeRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final sumSquares = samples.fold<double>(0.0, (sum, s) => sum + s * s);
    return math.sqrt(sumSquares / samples.length);
  }

  void reset() {
    _smoothedEnergy = 0.0;
    _isVoiceActive = false;
    _silenceStartTime = 0.0;
    _voiceStartTime = 0.0;
    _audioTime = 0.0;
  }

  void updateSensitivity(double threshold) {
    sensitivityThreshold = threshold;
  }
}
