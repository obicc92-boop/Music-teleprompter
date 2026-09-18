import 'package:flutter/foundation.dart';

/// Lets the screen on show decide what Android's back gesture does: the
/// editor saves before going home, a song asks twice while it plays.
class BackDispatcher {
  VoidCallback? _handler;

  void register(VoidCallback handler) => _handler = handler;

  /// Only clears [handler] if it's still the current one: the next song's
  /// screen registers before the previous one is disposed.
  void unregister(VoidCallback handler) {
    if (_handler == handler) _handler = null;
  }

  /// Runs the current screen's handler; false when there is none.
  bool handle() {
    final handler = _handler;
    if (handler == null) return false;
    handler();
    return true;
  }
}
