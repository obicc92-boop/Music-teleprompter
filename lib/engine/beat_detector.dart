import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import '../utils/constants.dart';

class BeatEvent {
  final double timestamp;
  final double estimatedBpm;
  final double energy;

  const BeatEvent({
    required this.timestamp,
    required this.estimatedBpm,
    required this.energy,
  });
}

class BeatDetector {
  final int sampleRate;
  final int windowSize;

  late final FFT _fft;

  final List<double> _beatTimes = [];
  final List<double> _energyHistory = [];
  double _previousEnergy = 0.0;
  double _lastBeatTime = 0.0;
  double _currentBpm = AudioConstants.defaultBpm;
  double _audioTime = 0.0;

  static const int _energyHistorySize = 43;
  static const double _minBeatIntervalMs = 250.0;

  BeatDetector({
    this.sampleRate = AudioConstants.sampleRate,
    this.windowSize = AudioConstants.fftWindowSize,
  }) {
    _fft = FFT(windowSize);
  }

  BeatEvent? processSamples(List<double> samples) {
    if (samples.length < windowSize) return null;

    _audioTime += samples.length / sampleRate;

    final windowed = _applyHannWindow(samples.sublist(0, windowSize));
    final energy = _computeSpectralFlux(windowed);

    _energyHistory.add(energy);
    if (_energyHistory.length > _energyHistorySize) {
      _energyHistory.removeAt(0);
    }

    final localAverage = _energyHistory.isEmpty
        ? 0.0
        : _energyHistory.reduce((a, b) => a + b) / _energyHistory.length;

    final timeSinceLastBeat = (_audioTime - _lastBeatTime) * 1000;
    final isBeat = energy > localAverage * AudioConstants.beatEnergyThreshold &&
        energy > _previousEnergy &&
        timeSinceLastBeat > _minBeatIntervalMs;

    _previousEnergy = energy;

    if (isBeat) {
      _lastBeatTime = _audioTime;
      _beatTimes.add(_audioTime);
      if (_beatTimes.length > AudioConstants.bpmAverageWindow) {
        _beatTimes.removeAt(0);
      }
      _currentBpm = _estimateBpm();
      return BeatEvent(
        timestamp: _audioTime,
        estimatedBpm: _currentBpm,
        energy: energy,
      );
    }

    return null;
  }

  double get currentBpm => _currentBpm;

  double _estimateBpm() {
    if (_beatTimes.length < 2) return _currentBpm;

    final intervals = <double>[];
    for (int i = 1; i < _beatTimes.length; i++) {
      intervals.add(_beatTimes[i] - _beatTimes[i - 1]);
    }

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    if (avgInterval <= 0) return _currentBpm;

    final rawBpm = 60.0 / avgInterval;
    final clamped = rawBpm.clamp(AudioConstants.minBpm, AudioConstants.maxBpm);
    _currentBpm = _currentBpm * 0.7 + clamped * 0.3;
    return _currentBpm;
  }

  Float64List _applyHannWindow(List<double> samples) {
    final result = Float64List(samples.length);
    final n = samples.length;
    for (int i = 0; i < n; i++) {
      final window = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (n - 1)));
      result[i] = samples[i] * window;
    }
    return result;
  }

  double _computeSpectralFlux(Float64List windowed) {
    // fftea realFft returns Float64x2List: each element is (real, imag)
    final freq = _fft.realFft(windowed);
    double flux = 0.0;
    final bins = freq.length;
    for (int i = 1; i < bins; i++) {
      final real = freq[i].x;
      final imag = freq[i].y;
      final mag = math.sqrt(real * real + imag * imag);
      flux += mag;
    }
    return bins > 0 ? flux / bins : 0.0;
  }

  void reset() {
    _beatTimes.clear();
    _energyHistory.clear();
    _previousEnergy = 0.0;
    _lastBeatTime = 0.0;
    _audioTime = 0.0;
    _currentBpm = AudioConstants.defaultBpm;
  }
}
