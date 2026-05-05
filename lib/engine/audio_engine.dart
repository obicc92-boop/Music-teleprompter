import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'beat_detector.dart';
import 'voice_detection_layer.dart';
import 'voice_profiler.dart';
import '../utils/constants.dart';

enum AudioEngineState { idle, starting, running, stopping, error }

class AudioEngine {
  final BeatDetector _beatDetector;
  final VoiceDetectionLayer _voiceLayer;
  final AudioRecorder _recorder = AudioRecorder();

  AudioEngineState _state = AudioEngineState.idle;
  StreamSubscription<Uint8List>? _audioSubscription;

  final StreamController<BeatEvent> _beatController =
      StreamController<BeatEvent>.broadcast();
  final StreamController<VoiceState> _voiceController =
      StreamController<VoiceState>.broadcast();
  final StreamController<AudioEngineState> _stateController =
      StreamController<AudioEngineState>.broadcast();

  Stream<BeatEvent> get beatStream => _beatController.stream;
  Stream<VoiceState> get voiceStream => _voiceController.stream;
  Stream<AudioEngineState> get stateStream => _stateController.stream;

  VoiceProfiler? voiceProfiler;

  AudioEngineState get state => _state;
  double get currentBpm => _beatDetector.currentBpm;
  bool get isRunning => _state == AudioEngineState.running;

  AudioEngine({
    double voiceSensitivity = AudioConstants.voiceEnergyThreshold,
  })  : _beatDetector = BeatDetector(
          sampleRate: AudioConstants.sampleRate,
          windowSize: AudioConstants.fftWindowSize,
        ),
        _voiceLayer = VoiceDetectionLayer(
          sensitivityThreshold: voiceSensitivity,
        );

  Future<bool> start() async {
    if (_state == AudioEngineState.running) return true;

    _setState(AudioEngineState.starting);

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _setState(AudioEngineState.error);
        return false;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AudioConstants.sampleRate,
          numChannels: 1,
          bitRate: 16 * AudioConstants.sampleRate,
        ),
      );

      _audioSubscription = stream.listen(
        _processAudioChunk,
        onError: (e) {
          debugPrint('Audio stream error: $e');
          _setState(AudioEngineState.error);
        },
        cancelOnError: false,
      );

      _setState(AudioEngineState.running);
      return true;
    } catch (e) {
      debugPrint('AudioEngine start failed: $e');
      _setState(AudioEngineState.error);
      return false;
    }
  }

  Future<void> stop() async {
    if (_state == AudioEngineState.idle) return;
    _setState(AudioEngineState.stopping);

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    _beatDetector.reset();
    _voiceLayer.reset();
    _setState(AudioEngineState.idle);
  }

  void updateVoiceSensitivity(double threshold) {
    _voiceLayer.updateSensitivity(threshold);
  }

  void _processAudioChunk(Uint8List bytes) {
    if (_state != AudioEngineState.running) return;

    final samples = _int16BytesToDoubles(bytes);
    if (samples.isEmpty) return;

    final beatEvent = _beatDetector.processSamples(samples);
    if (beatEvent != null && !_beatController.isClosed) {
      _beatController.add(beatEvent);
    }

    final voiceState = _voiceLayer.processSamples(
      samples,
      AudioConstants.sampleRate,
    );
    if (!_voiceController.isClosed) {
      _voiceController.add(voiceState);
    }

    voiceProfiler?.processChunk(samples);
  }

  List<double> _int16BytesToDoubles(Uint8List bytes) {
    final samples = <double>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final int16 = bytes[i] | (bytes[i + 1] << 8);
      final signed = int16 >= 32768 ? int16 - 65536 : int16;
      samples.add(signed / 32768.0);
    }
    return samples;
  }

  void _setState(AudioEngineState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _beatController.close();
    await _voiceController.close();
    await _stateController.close();
    _recorder.dispose();
  }
}
