import 'dart:math' as math;
import '../utils/constants.dart';

class VoiceState {
  final bool isActive;
  final double energy;
  final double smoothedEnergy;
  final double timestamp;
  final bool hasOnset;

  const VoiceState({
    required this.isActive,
    required this.energy,
    required this.smoothedEnergy,
    required this.timestamp,
    this.hasOnset = false,
  });
}

class VoiceDetectionLayer {
  double sensitivityThreshold;

  double _smoothedEnergy = 0.0;
  bool _isVoiceActive = false;
  bool _prevRawVoice = false;
  double _silenceStartTime = 0.0;
  double _voiceStartTime = 0.0;
  double _audioTime = 0.0;

  // Exponential smoothing constants
  static const double _attackSmoothing = 0.3;
  static const double _releaseSmoothing = 0.05;
  static const double _minVoiceDurationMs = 80.0;
  static const double _minSilenceDurationMs = 300.0;

  // Onset detection state
  // Detects the rising edge of each new syllable/word using energy flux.
  // _onsetArmed prevents multiple firings from the same onset — must drop below
  // arm threshold before the next onset can trigger.
  double _onsetPrevEnergy = 0.0;
  double _onsetFlux = 0.0;
  bool _onsetArmed = true;
  int _samplesSinceOnset = 0;

  static const double _onsetFluxThreshold = 0.004;
  static const double _onsetArmThreshold = 0.002;
  static const int _minOnsetIntervalMs = 100;

  VoiceDetectionLayer({
    this.sensitivityThreshold = AudioConstants.voiceEnergyThreshold,
  });

  VoiceState processSamples(List<double> samples, int sampleRate) {
    _audioTime += samples.length / sampleRate;

    final rms = _computeRms(samples);
    final smoothing = rms > _smoothedEnergy ? _attackSmoothing : _releaseSmoothing;
    _smoothedEnergy = _smoothedEnergy * (1.0 - smoothing) + rms * smoothing;

    final rawVoice = _smoothedEnergy > sensitivityThreshold;

    // Record transition times only on rising/falling edges, not every frame.
    if (rawVoice && !_prevRawVoice) {
      _voiceStartTime = _audioTime;
    } else if (!rawVoice && _prevRawVoice) {
      _silenceStartTime = _audioTime;
    }
    _prevRawVoice = rawVoice;

    final voiceDuration = (_audioTime - _voiceStartTime) * 1000;
    final silenceDuration = (_audioTime - _silenceStartTime) * 1000;

    if (!_isVoiceActive && rawVoice && voiceDuration > _minVoiceDurationMs) {
      _isVoiceActive = true;
    } else if (_isVoiceActive && !rawVoice && silenceDuration > _minSilenceDurationMs) {
      _isVoiceActive = false;
    }

    final onset = _checkOnset(samples.length, sampleRate);

    return VoiceState(
      isActive: _isVoiceActive,
      energy: rms,
      smoothedEnergy: _smoothedEnergy,
      timestamp: _audioTime,
      hasOnset: onset,
    );
  }

  // Returns true once per rising energy edge while voice is active.
  // Uses a peak-picking arm/disarm cycle so a single onset fires exactly once.
  bool _checkOnset(int sampleCount, int sampleRate) {
    _samplesSinceOnset += sampleCount;

    final rise = _smoothedEnergy - _onsetPrevEnergy;
    _onsetPrevEnergy = _smoothedEnergy;

    // Smooth only positive rises (energy increases = new sound starting)
    _onsetFlux = _onsetFlux * 0.4 + (rise > 0 ? rise : 0.0) * 0.6;

    // Re-arm once flux has decayed back down (peak has passed)
    if (!_onsetArmed && _onsetFlux < _onsetArmThreshold) {
      _onsetArmed = true;
    }

    final minSamples = _minOnsetIntervalMs * sampleRate ~/ 1000;
    if (_isVoiceActive &&
        _onsetArmed &&
        _onsetFlux > _onsetFluxThreshold &&
        _samplesSinceOnset >= minSamples) {
      _samplesSinceOnset = 0;
      _onsetArmed = false;
      return true;
    }
    return false;
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
    _prevRawVoice = false;
    _silenceStartTime = 0.0;
    _voiceStartTime = 0.0;
    _audioTime = 0.0;
    _onsetPrevEnergy = 0.0;
    _onsetFlux = 0.0;
    _onsetArmed = true;
    _samplesSinceOnset = 0;
  }

  void updateSensitivity(double threshold) {
    sensitivityThreshold = threshold;
  }
}
