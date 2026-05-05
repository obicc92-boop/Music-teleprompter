import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

/// Mel-frequency cepstral coefficient extractor.
/// Uses the same fftea FFT backend as BeatDetector.
class MfccExtractor {
  static const int numFilters = 26;
  static const int numCoeffs = 13;
  static const double _preEmphasis = 0.97;

  final int sampleRate;
  final int frameSize;

  late final FFT _fft;
  late final List<double> _hammingWindow;
  late final List<List<double>> _melFilters; // [numFilters][numBins]
  late final List<List<double>> _dctMatrix;  // [numCoeffs][numFilters]

  MfccExtractor({this.sampleRate = 44100, this.frameSize = 1024}) {
    _fft = FFT(frameSize);
    _hammingWindow = _buildHammingWindow();
    _melFilters = _buildMelFilterBank(
      80.0,
      math.min(8000.0, sampleRate / 2.0),
    );
    _dctMatrix = _buildDctMatrix();
  }

  // ── Window ────────────────────────────────────────────────────────────────

  List<double> _buildHammingWindow() => List.generate(
        frameSize,
        (n) => 0.54 - 0.46 * math.cos(2 * math.pi * n / (frameSize - 1)),
      );

  // ── Mel filter bank ───────────────────────────────────────────────────────

  static double _hzToMel(double hz) =>
      2595.0 * math.log(1.0 + hz / 700.0) / math.ln10;

  static double _melToHz(double mel) =>
      700.0 * (math.pow(10.0, mel / 2595.0) - 1.0);

  List<List<double>> _buildMelFilterBank(double minHz, double maxHz) {
    final numBins = frameSize ~/ 2 + 1;
    final minMel = _hzToMel(minHz);
    final maxMel = _hzToMel(maxHz);

    // (numFilters + 2) evenly spaced mel points
    final melPts = List.generate(
      numFilters + 2,
      (i) => minMel + i * (maxMel - minMel) / (numFilters + 1),
    );

    // Convert mel points to FFT bin indices
    final bins = melPts
        .map((m) =>
            (_melToHz(m) / sampleRate * frameSize).round().clamp(0, numBins - 1))
        .toList();

    return List.generate(numFilters, (m) {
      final filter = List<double>.filled(numBins, 0.0);
      final left = bins[m];
      final center = bins[m + 1];
      final right = bins[m + 2];
      if (center > left) {
        for (int k = left; k < center; k++) {
          filter[k] = (k - left) / (center - left);
        }
      }
      if (right > center) {
        for (int k = center; k < right; k++) {
          filter[k] = (right - k) / (right - center);
        }
      }
      return filter;
    });
  }

  // ── DCT matrix ────────────────────────────────────────────────────────────

  List<List<double>> _buildDctMatrix() {
    final scale = math.sqrt(2.0 / numFilters);
    return List.generate(
      numCoeffs,
      (i) => List.generate(
        numFilters,
        (j) => scale *
            math.cos(math.pi * i * (2 * j + 1) / (2.0 * numFilters)),
      ),
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Extracts [numCoeffs] MFCC values from a [frameSize] PCM frame.
  List<double> extract(List<double> frame) {
    final n = math.min(frame.length, frameSize);
    final numBins = frameSize ~/ 2 + 1;

    // Pre-emphasis + Hamming window
    final windowed = Float64List(frameSize);
    windowed[0] = frame[0] * _hammingWindow[0];
    for (int i = 1; i < n; i++) {
      windowed[i] =
          (frame[i] - _preEmphasis * frame[i - 1]) * _hammingWindow[i];
    }

    // Power spectrum — same pattern as BeatDetector: realFft returns Float64x2List
    final freq = _fft.realFft(windowed);
    final power = List<double>.filled(numBins, 0.0);
    for (int i = 0; i < numBins; i++) {
      final r = freq[i].x;
      final im = freq[i].y;
      power[i] = (r * r + im * im) / frameSize;
    }

    // Mel filter bank → log energy
    final logMel = List<double>.filled(numFilters, 0.0);
    for (int m = 0; m < numFilters; m++) {
      double energy = 0.0;
      for (int k = 0; k < numBins; k++) {
        energy += _melFilters[m][k] * power[k];
      }
      logMel[m] = math.log(energy + 1e-10);
    }

    // DCT
    final mfccs = List<double>.filled(numCoeffs, 0.0);
    for (int i = 0; i < numCoeffs; i++) {
      for (int j = 0; j < numFilters; j++) {
        mfccs[i] += _dctMatrix[i][j] * logMel[j];
      }
    }
    return mfccs;
  }
}
