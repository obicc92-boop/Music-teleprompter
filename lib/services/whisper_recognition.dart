import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'word_recognition_service.dart';

/// Runs whisper-cli as a subprocess to transcribe 3-second audio chunks.
/// [wordTimestamps] = false → plain text mode (Whisper).
/// [wordTimestamps] = true  → token-level JSON mode (Whisper Align).
///
/// Requires whisper.cpp installed: brew install whisper-cpp
/// Models: whisper-download-ggml-model base.en
class WhisperRecognition implements WordRecognitionService {
  final Stream<Uint8List> rawAudioStream;
  final String modelPath;
  final bool wordTimestamps;

  String _lyrics = '';
  final StreamController<String> _controller = StreamController.broadcast();
  StreamSubscription<Uint8List>? _audioSub;
  final List<int> _buffer = [];
  bool _processing = false;

  // 3 seconds of 16 kHz mono PCM16 = 16000 * 2 * 3 = 96 000 bytes
  static const int _chunkBytes = 16000 * 2 * 3;

  WhisperRecognition({
    required this.rawAudioStream,
    required this.modelPath,
    this.wordTimestamps = false,
  });

  @override
  Stream<String> get wordStream => _controller.stream;

  @override
  Future<void> start({required String lyrics}) async {
    _lyrics = lyrics;
    _buffer.clear();
    _processing = false;
    _audioSub = rawAudioStream.listen(_onBytes);
  }

  void _onBytes(Uint8List bytes) {
    _buffer.addAll(bytes);
    if (!_processing && _buffer.length >= _chunkBytes) {
      final chunk = Uint8List.fromList(_buffer.sublist(0, _chunkBytes));
      _buffer.removeRange(0, _chunkBytes);
      _processChunk(chunk);
    }
  }

  Future<void> _processChunk(Uint8List pcm) async {
    _processing = true;
    try {
      final tmpDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final wavPath = '${tmpDir.path}/wsp_$ts.wav';
      await File(wavPath).writeAsBytes(_buildWav(pcm));

      final result = await Process.run('whisper-cli', _args(wavPath));
      try { await File(wavPath).delete(); } catch (_) {}

      if (result.exitCode == 0) {
        final words = wordTimestamps
            ? _parseJson(result.stdout as String)
            : _parseTxt(result.stdout as String);
        for (final w in words) {
          if (!_controller.isClosed) _controller.add(w);
        }
      }
    } catch (_) {
      // whisper-cli not found or execution blocked — fail silently
    }
    _processing = false;
  }

  List<String> _args(String wavPath) {
    final prompt = _lyrics.isEmpty ? '' : _lyrics.substring(0, min(224, _lyrics.length));
    return [
      '--model', modelPath,
      '--file', wavPath,
      '--language', 'en',
      '--no-prints',
      if (wordTimestamps) ...['--output-json-full', '--split-on-word']
      else ...['--output-txt', '--no-timestamps'],
      if (prompt.isNotEmpty) ...['--initial-prompt', prompt],
    ];
  }

  List<String> _parseTxt(String out) =>
      out.split(RegExp(r'\s+')).map(_clean).where((w) => w.isNotEmpty).toList();

  List<String> _parseJson(String out) {
    try {
      final decoded = jsonDecode(out) as Map<String, dynamic>;
      final segments = (decoded['transcription'] as List<dynamic>?) ?? [];
      final words = <String>[];
      for (final seg in segments) {
        for (final tok in (seg['tokens'] as List<dynamic>? ?? [])) {
          final w = _clean((tok['text'] as String? ?? '').trim());
          if (w.isNotEmpty) words.add(w);
        }
      }
      return words.isNotEmpty ? words : _parseTxt(out);
    } catch (_) {
      return _parseTxt(out);
    }
  }

  String _clean(String w) => w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// Write a minimal PCM-16 mono 16 kHz WAV.
  Uint8List _buildWav(Uint8List pcm) {
    final size = pcm.length;
    final h = ByteData(44);
    void s(int o, String v) {
      for (int i = 0; i < v.length; i++) { h.setUint8(o + i, v.codeUnitAt(i)); }
    }
    s(0, 'RIFF'); h.setUint32(4, 36 + size, Endian.little);
    s(8, 'WAVE'); s(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);   // PCM
    h.setUint16(22, 1, Endian.little);   // mono
    h.setUint32(24, 16000, Endian.little);
    h.setUint32(28, 32000, Endian.little); // byteRate
    h.setUint16(32, 2, Endian.little);   // blockAlign
    h.setUint16(34, 16, Endian.little);  // bitsPerSample
    s(36, 'data'); h.setUint32(40, size, Endian.little);
    final wav = Uint8List(44 + size);
    wav.setAll(0, h.buffer.asUint8List());
    wav.setAll(44, pcm);
    return wav;
  }

  @override
  Future<void> stop() async {
    await _audioSub?.cancel();
    _audioSub = null;
    _buffer.clear();
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (!_controller.isClosed) await _controller.close();
  }
}
