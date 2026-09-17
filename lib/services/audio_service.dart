import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  String? _filePath;
  Duration? _duration;
  double _volume = 0.8;
  bool _loaded = false;

  String? get filePath => _filePath;
  String? get fileName => _filePath?.split('/').last.split('\\').last;
  Duration? get duration => _duration;
  double get volume => _volume;
  bool get isLoaded => _loaded;

  Stream<Duration> get positionStream => _player.positionStream;

  AudioService() {
    _player.setVolume(_volume);
  }

  Future<bool> loadFile(String path) async {
    try {
      _filePath = path;
      _duration = await _player.setFilePath(path);
      await _player.setVolume(_volume);
      _loaded = true;
      notifyListeners();
      return true;
    } catch (_) {
      _loaded = false;
      _filePath = null;
      _duration = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> play() async {
    if (!_loaded) return;
    // If at the very end, restart
    final pos = _player.position;
    final dur = _duration;
    if (dur != null && pos >= dur - const Duration(milliseconds: 500)) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  double get positionSeconds => _player.position.inMicroseconds / 1e6;

  Future<void> seek(Duration position) async {
    if (!_loaded) return;
    await _player.seek(position);
  }

  Future<void> seekToFraction(double fraction) async {
    final dur = _duration;
    if (dur == null || !_loaded) return;
    final target = Duration(
      milliseconds: (dur.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
    );
    await _player.seek(target);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  void unload() {
    _player.stop();
    _filePath = null;
    _loaded = false;
    _duration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
