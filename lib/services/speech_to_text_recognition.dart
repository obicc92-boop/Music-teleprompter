import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'word_recognition_service.dart';

class SpeechToTextRecognition implements WordRecognitionService {
  final SpeechToText _speech = SpeechToText();
  final StreamController<String> _controller = StreamController.broadcast();

  bool _isListening = false;
  String _lastPartial = '';

  @override
  Stream<String> get wordStream => _controller.stream;

  @override
  Future<void> start({required String lyrics}) async {
    final available = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    if (!available || _controller.isClosed) return;
    _isListening = true;
    _startListen();
  }

  void _startListen() {
    if (!_isListening || _controller.isClosed) return;
    _lastPartial = '';
    _speech.listen(
      onResult: _onResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    final current = result.recognizedWords;
    if (current.length > _lastPartial.length) {
      final newText = current.substring(_lastPartial.length).trim();
      for (final word in newText.split(RegExp(r'\s+'))) {
        final cleaned = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (cleaned.isNotEmpty && !_controller.isClosed) {
          _controller.add(cleaned);
        }
      }
    }
    _lastPartial = current;
    if (result.finalResult && _isListening) {
      _startListen();
    }
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    await _speech.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (!_controller.isClosed) await _controller.close();
  }
}
