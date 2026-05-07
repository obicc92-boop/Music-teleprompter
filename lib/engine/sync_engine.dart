import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_engine.dart';
import 'beat_detector.dart';
import 'voice_detection_layer.dart';
import 'voice_profiler.dart';
import '../utils/constants.dart';

enum PlayState { stopped, playing, paused }

class SyncEngineState {
  final double bpm;
  final bool isVoiceActive;
  final double voiceEnergy;
  final double scrollSpeed;
  final double manualMultiplier;
  final PlayState playState;
  final AudioEngineState audioState;

  const SyncEngineState({
    this.bpm = AudioConstants.defaultBpm,
    this.isVoiceActive = false,
    this.voiceEnergy = 0.0,
    this.scrollSpeed = 0.0,
    this.manualMultiplier = ScrollConstants.defaultSpeedMultiplier,
    this.playState = PlayState.stopped,
    this.audioState = AudioEngineState.idle,
  });

  SyncEngineState copyWith({
    double? bpm,
    bool? isVoiceActive,
    double? voiceEnergy,
    double? scrollSpeed,
    double? manualMultiplier,
    PlayState? playState,
    AudioEngineState? audioState,
  }) {
    return SyncEngineState(
      bpm: bpm ?? this.bpm,
      isVoiceActive: isVoiceActive ?? this.isVoiceActive,
      voiceEnergy: voiceEnergy ?? this.voiceEnergy,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      manualMultiplier: manualMultiplier ?? this.manualMultiplier,
      playState: playState ?? this.playState,
      audioState: audioState ?? this.audioState,
    );
  }
}

class SyncEngine extends ChangeNotifier {
  final AudioEngine _audioEngine;

  SyncEngineState _state = const SyncEngineState();
  StreamSubscription<BeatEvent>? _beatSub;
  StreamSubscription<VoiceState>? _voiceSub;
  StreamSubscription<AudioEngineState>? _audioStateSub;

  double _smoothedScrollSpeed = 0.0;
  bool _useManualBpm = false;
  double _manualBpm = AudioConstants.defaultBpm;
  bool _autoScrollOnVoice = true;
  VoiceProfiler? _voiceProfiler;

  SyncEngineState get state => _state;
  PlayState get playState => _state.playState;
  double get bpm => _state.bpm;
  bool get isVoiceActive => _state.isVoiceActive;
  double get scrollSpeed => _state.scrollSpeed;
  bool get isPlaying => _state.playState == PlayState.playing;

  Stream<BeatEvent> get beatStream => _audioEngine.beatStream;

  SyncEngine({required AudioEngine audioEngine}) : _audioEngine = audioEngine {
    _wireStreams();
  }

  void _wireStreams() {
    _audioStateSub = _audioEngine.stateStream.listen((s) {
      _updateState(_state.copyWith(audioState: s));
    });
    _beatSub = _audioEngine.beatStream.listen(_onBeat);
    _voiceSub = _audioEngine.voiceStream.listen(_onVoice);
  }

  void _onBeat(BeatEvent event) {
    if (_useManualBpm) return;
    _updateState(_state.copyWith(bpm: event.estimatedBpm));
  }

  void _onVoice(VoiceState voiceState) {
    final isActive = (_voiceProfiler?.hasProfile ?? false)
        ? (_voiceProfiler!.isVoiceMatch && voiceState.isActive)
        : voiceState.isActive;
    _updateState(_state.copyWith(
      isVoiceActive: isActive,
      voiceEnergy: voiceState.smoothedEnergy,
    ));
  }

  void setVoiceProfiler(VoiceProfiler? profiler) {
    _voiceProfiler = profiler;
    _audioEngine.voiceProfiler = profiler;
  }

  /// Called every frame by ScrollEngine. Computes target fresh from current
  /// state and smooths toward it — single smoothing pass, no stale targets.
  double tickScrollSpeed(double dt) {
    if (_state.playState != PlayState.playing) {
      _smoothedScrollSpeed = 0.0;
      return 0.0;
    }

    final effectiveBpm = _useManualBpm ? _manualBpm : _state.bpm;
    final bpmFactor = effectiveBpm / AudioConstants.defaultBpm;

    double voiceFactor;
    if (_autoScrollOnVoice) {
      voiceFactor = _state.isVoiceActive
          ? ScrollConstants.voiceSpeedBoost
          : ScrollConstants.silenceSpeedReduction;
    } else {
      voiceFactor = 1.0;
    }

    final target = ScrollConstants.pixelsPerSecondBase *
        bpmFactor *
        voiceFactor *
        _state.manualMultiplier;

    _smoothedScrollSpeed +=
        (target - _smoothedScrollSpeed) * ScrollConstants.speedSmoothingFactor;

    _updateState(_state.copyWith(scrollSpeed: _smoothedScrollSpeed));
    return _smoothedScrollSpeed * dt;
  }

  Future<void> play() async {
    if (_state.playState == PlayState.playing) return;
    _updateState(_state.copyWith(playState: PlayState.playing));
    await _audioEngine.start();
  }

  Future<void> pause() async {
    if (_state.playState != PlayState.playing) return;
    _smoothedScrollSpeed = 0.0;
    _updateState(_state.copyWith(
      playState: PlayState.paused,
      scrollSpeed: 0.0,
    ));
  }

  Future<void> stop() async {
    _smoothedScrollSpeed = 0.0;
    _updateState(_state.copyWith(
      playState: PlayState.stopped,
      scrollSpeed: 0.0,
    ));
    await _audioEngine.stop();
  }

  Future<void> togglePlayPause() async {
    if (_state.playState == PlayState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  void setManualMultiplier(double value) {
    _updateState(_state.copyWith(
      manualMultiplier: value.clamp(
        ScrollConstants.minSpeedMultiplier,
        ScrollConstants.maxSpeedMultiplier,
      ),
    ));
  }

  void adjustSpeed(double delta) {
    setManualMultiplier(_state.manualMultiplier + delta);
  }

  void setManualBpm(double bpm) {
    _manualBpm = bpm.clamp(AudioConstants.minBpm, AudioConstants.maxBpm);
  }

  void setUseManualBpm(bool value) {
    _useManualBpm = value;
    if (value) _updateState(_state.copyWith(bpm: _manualBpm));
  }

  void setAutoScrollOnVoice(bool value) {
    _autoScrollOnVoice = value;
  }

  void updateVoiceSensitivity(double threshold) {
    _audioEngine.updateVoiceSensitivity(threshold);
  }

  void _updateState(SyncEngineState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _beatSub?.cancel();
    await _voiceSub?.cancel();
    await _audioStateSub?.cancel();
    await _audioEngine.dispose();
    super.dispose();
  }
}
