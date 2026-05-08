enum WordSyncMode { off, onset, systemStt, whisper, whisperAlign }

abstract class WordRecognitionService {
  /// Stream of recognized words — lowercase, letters only, no punctuation.
  Stream<String> get wordStream;

  /// Start recognition. [lyrics] is fed as context to the ASR engine.
  Future<void> start({required String lyrics});

  Future<void> stop();
  Future<void> dispose();
}
