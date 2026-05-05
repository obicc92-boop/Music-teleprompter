import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'mfcc_extractor.dart';
import '../utils/constants.dart';

class VoiceProfiler extends ChangeNotifier {
  static const int totalEnrollmentSamples = 5;
  static const double sampleDurationSeconds = 3.0;
  static const double matchThreshold = 0.72;
  static const double _smoothingFactor = 0.12;
  static const int _frameSize = AudioConstants.fftWindowSize;

  final MfccExtractor _mfcc = MfccExtractor(
    sampleRate: AudioConstants.sampleRate,
    frameSize: _frameSize,
  );
  final AudioRecorder _enrollRecorder = AudioRecorder();

  List<double>? _profile;
  final List<List<double>> _enrollmentVectors = [];
  double _matchScore = 0.0;
  bool _isEnrolling = false;
  int _enrolledCount = 0;

  // Adaptive noise floor (fast attack, slow release)
  double _noiseFloor = 0.001;

  // Rolling sample buffer for real-time frame extraction
  final List<double> _sampleBuffer = [];

  bool get hasProfile => _profile != null;
  bool get isEnrolling => _isEnrolling;
  int get enrolledCount => _enrolledCount;
  double get matchScore => _matchScore;
  bool get isVoiceMatch => hasProfile && _matchScore >= matchThreshold;
  List<double>? get profileVector => _profile != null ? List.unmodifiable(_profile!) : null;

  /// Called by AudioEngine on every PCM chunk during playback.
  void processChunk(List<double> samples) {
    if (_profile == null || _isEnrolling) return;

    _sampleBuffer.addAll(samples);
    while (_sampleBuffer.length >= _frameSize) {
      final frame = _sampleBuffer.sublist(0, _frameSize);
      _sampleBuffer.removeRange(0, _frameSize);
      _processFrame(frame);
    }

  }

  void _processFrame(List<double> frame) {
    double energy = 0.0;
    for (final s in frame) { energy += s * s; }
    energy /= frame.length;

    // Adaptive noise floor
    if (energy > _noiseFloor) {
      _noiseFloor = _noiseFloor * 0.85 + energy * 0.15;
    } else {
      _noiseFloor = _noiseFloor * 0.997 + energy * 0.003;
    }

    if (energy < _noiseFloor * 4.0) return;

    final mfccs = _mfcc.extract(frame);
    final sim = _cosineSimilarity(mfccs, _profile!);
    _matchScore = _matchScore * (1.0 - _smoothingFactor) + sim * _smoothingFactor;
    notifyListeners();
  }

  /// Records one enrollment sample (3 seconds) and accumulates its MFCC mean.
  /// [onProgress] is called with a 0.0–1.0 value as recording proceeds.
  Future<bool> enrollSample({required void Function(double) onProgress}) async {
    if (_isEnrolling) return false;
    if (_enrolledCount >= totalEnrollmentSamples) return false;

    _isEnrolling = true;
    notifyListeners();

    try {
      final hasPermission = await _enrollRecorder.hasPermission();
      if (!hasPermission) {
        _isEnrolling = false;
        notifyListeners();
        return false;
      }

      final List<double> pendingSamples = [];
      final List<double> allMfccs = [];
      final completer = Completer<void>();
      final elapsed = Stopwatch()..start();

      final stream = await _enrollRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AudioConstants.sampleRate,
          numChannels: 1,
          bitRate: 16 * AudioConstants.sampleRate,
        ),
      );

      StreamSubscription<Uint8List>? sub;
      sub = stream.listen((bytes) {
        final progress =
            elapsed.elapsed.inMilliseconds / (sampleDurationSeconds * 1000);
        onProgress(progress.clamp(0.0, 1.0));

        for (int i = 0; i + 1 < bytes.length; i += 2) {
          final raw = bytes[i] | (bytes[i + 1] << 8);
          final signed = raw >= 32768 ? raw - 65536 : raw;
          pendingSamples.add(signed / 32768.0);
        }

        while (pendingSamples.length >= _frameSize) {
          final frame = pendingSamples.sublist(0, _frameSize);
          pendingSamples.removeRange(0, _frameSize);

          double energy = 0.0;
          for (final s in frame) { energy += s * s; }
          energy /= frame.length;

          if (energy > 0.0005) {
            allMfccs.addAll(_mfcc.extract(frame));
          }
        }

        if (elapsed.elapsed.inMilliseconds >= sampleDurationSeconds * 1000 &&
            !completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future;
      await sub.cancel();
      if (await _enrollRecorder.isRecording()) await _enrollRecorder.stop();
      onProgress(1.0);

      if (allMfccs.isNotEmpty) {
        const numCoeffs = MfccExtractor.numCoeffs;
        final numFrames = allMfccs.length ~/ numCoeffs;
        final mean = List<double>.filled(numCoeffs, 0.0);
        for (int f = 0; f < numFrames; f++) {
          for (int c = 0; c < numCoeffs; c++) {
            mean[c] += allMfccs[f * numCoeffs + c];
          }
        }
        for (int c = 0; c < numCoeffs; c++) { mean[c] /= numFrames; }
        _enrollmentVectors.add(mean);
        _enrolledCount++;
      }

      _isEnrolling = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('VoiceProfiler enrollment error: $e');
      _isEnrolling = false;
      notifyListeners();
      return false;
    }
  }

  /// Averages all enrollment vectors and applies CMN; sets the active profile.
  void buildProfile() {
    if (_enrollmentVectors.isEmpty) return;

    const numCoeffs = MfccExtractor.numCoeffs;
    final mean = List<double>.filled(numCoeffs, 0.0);
    for (final vec in _enrollmentVectors) {
      for (int c = 0; c < numCoeffs; c++) { mean[c] += vec[c]; }
    }
    for (int c = 0; c < numCoeffs; c++) { mean[c] /= _enrollmentVectors.length; }

    // Cepstral Mean Normalization: subtract the mean of all coefficients
    double cmn = 0.0;
    for (final v in mean) { cmn += v; }
    cmn /= numCoeffs;
    for (int c = 0; c < numCoeffs; c++) { mean[c] -= cmn; }

    _profile = mean;
    notifyListeners();
  }

  /// Restores a previously saved profile vector.
  void loadProfile(List<double> vector) {
    _profile = List<double>.from(vector);
    _enrolledCount = totalEnrollmentSamples;
    notifyListeners();
  }

  void clearProfile() {
    _profile = null;
    _enrollmentVectors.clear();
    _enrolledCount = 0;
    _matchScore = 0.0;
    _sampleBuffer.clear();
    notifyListeners();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    return denom < 1e-10 ? 0.0 : (dot / denom).clamp(-1.0, 1.0);
  }

  @override
  void dispose() {
    _enrollRecorder.dispose();
    super.dispose();
  }
}
