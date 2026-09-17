import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

enum PlayState { stopped, playing, paused }

class SyncEngineState {
  final double scrollSpeed;
  final double manualMultiplier;
  final PlayState playState;

  const SyncEngineState({
    this.scrollSpeed = 0.0,
    this.manualMultiplier = ScrollConstants.defaultSpeedMultiplier,
    this.playState = PlayState.stopped,
  });

  SyncEngineState copyWith({
    double? scrollSpeed,
    double? manualMultiplier,
    PlayState? playState,
  }) =>
      SyncEngineState(
        scrollSpeed: scrollSpeed ?? this.scrollSpeed,
        manualMultiplier: manualMultiplier ?? this.manualMultiplier,
        playState: playState ?? this.playState,
      );
}

class SyncEngine extends ChangeNotifier {
  SyncEngineState _state = const SyncEngineState();

  SyncEngineState get state => _state;
  PlayState get playState => _state.playState;
  bool get isPlaying => _state.playState == PlayState.playing;
  double get scrollSpeed => _state.scrollSpeed;

  /// Called every frame by ScrollEngine. Returns pixels to advance this frame.
  double tickScrollSpeed(double dt) {
    if (_state.playState != PlayState.playing) return 0.0;
    final speed = ScrollConstants.pixelsPerSecondBase * _state.manualMultiplier;
    _updateState(_state.copyWith(scrollSpeed: speed));
    return speed * dt;
  }

  Future<void> play() async {
    if (_state.playState == PlayState.playing) return;
    _updateState(_state.copyWith(playState: PlayState.playing));
  }

  Future<void> pause() async {
    if (_state.playState != PlayState.playing) return;
    _updateState(_state.copyWith(playState: PlayState.paused, scrollSpeed: 0.0));
  }

  Future<void> stop() async {
    _updateState(_state.copyWith(playState: PlayState.stopped, scrollSpeed: 0.0));
  }

  Future<void> togglePlayPause() async {
    if (_state.playState == PlayState.playing) {
      await pause();
    } else {
      await play();
    }
  }

  void setManualMultiplier(double value) {
    final clamped = value.clamp(
      ScrollConstants.minSpeedMultiplier,
      ScrollConstants.maxSpeedMultiplier,
    );
    // Hundredths keep repeated steps exact (1.05, not 1.0500000000000003)
    _updateState(_state.copyWith(
      manualMultiplier: (clamped * 100).round() / 100,
    ));
  }

  void adjustSpeed(double delta) {
    setManualMultiplier(_state.manualMultiplier + delta);
  }

  void _updateState(SyncEngineState newState) {
    _state = newState;
    notifyListeners();
  }

}
