/// Work that has to reach disk before the app closes or goes to the
/// background: an editor holding words typed a moment ago registers here
/// and is flushed when the window is closed or the phone switches apps.
class PendingSaves {
  PendingSaves._();

  static final _flushers = <Future<void> Function()>[];

  static void register(Future<void> Function() flush) =>
      _flushers.add(flush);

  static void unregister(Future<void> Function() flush) =>
      _flushers.remove(flush);

  /// Runs every registered flush; a failure in one doesn't stop the others.
  static Future<void> flush() async {
    for (final flush in List.of(_flushers)) {
      try {
        await flush();
      } catch (_) {}
    }
  }
}
