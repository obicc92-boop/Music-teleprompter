import 'dart:convert';
import 'package:flutter/services.dart';

/// Where a shortcut is listed in Settings.
enum ShortcutGroup {
  playback('Playback'),
  navigation('Navigation'),
  display('Display');

  const ShortcutGroup(this.title);
  final String title;
}

/// Everything a key can do on the song screen.
enum ShortcutAction {
  playPause('Play / pause', ShortcutGroup.playback),
  speedUp('Speed up', ShortcutGroup.playback),
  speedDown('Slow down', ShortcutGroup.playback),
  tapTempo('Tap tempo', ShortcutGroup.playback),
  resetToStart('Reset to start', ShortcutGroup.playback),
  loop('Toggle loop section', ShortcutGroup.playback),
  scrollUp('Scroll up', ShortcutGroup.navigation),
  scrollDown('Scroll down', ShortcutGroup.navigation),
  nextSection('Next section', ShortcutGroup.navigation),
  prevSection('Previous section', ShortcutGroup.navigation),
  nextSong('Next song', ShortcutGroup.navigation),
  prevSong('Previous song', ShortcutGroup.navigation),
  fullscreen('Toggle fullscreen', ShortcutGroup.display),
  mirror('Toggle mirror mode', ShortcutGroup.display),
  edit('Edit lyrics', ShortcutGroup.display),
  back('Back to setlist', ShortcutGroup.display);

  const ShortcutAction(this.label, this.group);
  final String label;
  final ShortcutGroup group;
}

/// One key, with any of Ctrl, Alt, Shift or ⌘ held with it.
class KeyBinding {
  final LogicalKeyboardKey key;
  final bool shift;
  final bool control;
  final bool alt;
  final bool meta;

  const KeyBinding(
    this.key, {
    this.shift = false,
    this.control = false,
    this.alt = false,
    this.meta = false,
  });

  /// The binding for a key that was just pressed, as it would be saved:
  /// numpad keys count as their main-keyboard twins, and Shift is only
  /// remembered for keys where it doesn't change the character typed.
  factory KeyBinding.fromEvent(KeyEvent event) {
    final key = normalise(event.logicalKey);
    final pressed = HardwareKeyboard.instance;
    return KeyBinding(
      key,
      shift: pressed.isShiftPressed && shiftMatters(key),
      control: pressed.isControlPressed,
      alt: pressed.isAltPressed,
      meta: pressed.isMetaPressed,
    );
  }

  /// Whether [event] is this key with these modifiers.
  bool matches(KeyEvent event) {
    if (normalise(event.logicalKey) != key) return false;
    final pressed = HardwareKeyboard.instance;
    if (pressed.isControlPressed != control) return false;
    if (pressed.isAltPressed != alt) return false;
    if (pressed.isMetaPressed != meta) return false;
    if (shiftMatters(key) && pressed.isShiftPressed != shift) return false;
    return true;
  }

  /// Keys whose numpad or shifted twin means the same thing.
  static LogicalKeyboardKey normalise(LogicalKeyboardKey key) =>
      _twins[key] ?? key;

  static final _twins = {
    LogicalKeyboardKey.add: LogicalKeyboardKey.equal,
    LogicalKeyboardKey.numpadAdd: LogicalKeyboardKey.equal,
    LogicalKeyboardKey.numpadSubtract: LogicalKeyboardKey.minus,
    LogicalKeyboardKey.numpadEnter: LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpad0: LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.numpad1: LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.numpad2: LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.numpad3: LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.numpad4: LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.numpad5: LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.numpad6: LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.numpad7: LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.numpad8: LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.numpad9: LogicalKeyboardKey.digit9,
  };

  /// Shift+K is a different shortcut from K, but Shift+= is just "+".
  static bool shiftMatters(LogicalKeyboardKey key) {
    final id = key.keyId;
    if (id >= LogicalKeyboardKey.keyA.keyId &&
        id <= LogicalKeyboardKey.keyZ.keyId) {
      return true;
    }
    if (id >= LogicalKeyboardKey.f1.keyId &&
        id <= LogicalKeyboardKey.f12.keyId) {
      return true;
    }
    return _shiftKeys.contains(key);
  }

  static final _shiftKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.insert,
    LogicalKeyboardKey.escape,
  };

  /// A modifier on its own isn't a shortcut.
  static bool isModifier(LogicalKeyboardKey key) => _modifiers.contains(key);

  static final _modifiers = {
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };

  /// Keys a foot pedal sends; they keep their pedal meaning.
  static bool isPedalKey(LogicalKeyboardKey key) =>
      _pedalKeys.contains(normalise(key));

  static final _pedalKeys = {
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.enter,
  };

  /// How the key reads on screen: "Space", "Ctrl+K", "↑", "+".
  String get label {
    final parts = <String>[
      if (control) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (meta) 'Cmd',
      keyName(key),
    ];
    return parts.join('+');
  }

  static String keyName(LogicalKeyboardKey key) {
    final name = _names[key];
    if (name != null) return name;
    final raw = key.keyLabel;
    return raw.length == 1 ? raw.toUpperCase() : raw;
  }

  static final _names = {
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.escape: 'Esc',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.insert: 'Insert',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.equal: '+',
    LogicalKeyboardKey.minus: '−',
  };

  Map<String, dynamic> toJson() => {
    'key': key.keyId,
    if (shift) 'shift': true,
    if (control) 'control': true,
    if (alt) 'alt': true,
    if (meta) 'meta': true,
  };

  static KeyBinding? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['key'];
    if (id is! int) return null;
    final key = LogicalKeyboardKey.findKeyByKeyId(id);
    if (key == null) return null;
    return KeyBinding(
      key,
      shift: json['shift'] == true,
      control: json['control'] == true,
      alt: json['alt'] == true,
      meta: json['meta'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KeyBinding &&
      other.key == key &&
      other.shift == shift &&
      other.control == control &&
      other.alt == alt &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(key, shift, control, alt, meta);

  @override
  String toString() => 'KeyBinding($label)';
}

/// The key for every action. Only what differs from the defaults is kept,
/// so a reset is just forgetting the change.
class ShortcutMap {
  /// An action → its key, or null when the user took the key away.
  final Map<ShortcutAction, KeyBinding?> _changes;

  const ShortcutMap([this._changes = const {}]);

  static const defaults = <ShortcutAction, KeyBinding>{
    ShortcutAction.playPause: KeyBinding(LogicalKeyboardKey.space),
    ShortcutAction.speedUp: KeyBinding(LogicalKeyboardKey.equal),
    ShortcutAction.speedDown: KeyBinding(LogicalKeyboardKey.minus),
    ShortcutAction.tapTempo: KeyBinding(LogicalKeyboardKey.keyT),
    ShortcutAction.resetToStart: KeyBinding(LogicalKeyboardKey.keyR),
    ShortcutAction.loop: KeyBinding(LogicalKeyboardKey.keyL),
    ShortcutAction.scrollUp: KeyBinding(LogicalKeyboardKey.arrowUp),
    ShortcutAction.scrollDown: KeyBinding(LogicalKeyboardKey.arrowDown),
    ShortcutAction.nextSection: KeyBinding(LogicalKeyboardKey.arrowRight),
    ShortcutAction.prevSection: KeyBinding(LogicalKeyboardKey.arrowLeft),
    ShortcutAction.nextSong: KeyBinding(LogicalKeyboardKey.keyN),
    ShortcutAction.prevSong: KeyBinding(LogicalKeyboardKey.keyP),
    ShortcutAction.fullscreen: KeyBinding(LogicalKeyboardKey.keyF),
    ShortcutAction.mirror: KeyBinding(LogicalKeyboardKey.keyM),
    ShortcutAction.edit: KeyBinding(LogicalKeyboardKey.keyE),
    ShortcutAction.back: KeyBinding(LogicalKeyboardKey.escape),
  };

  /// The key for [action], or null when it has none.
  KeyBinding? bindingFor(ShortcutAction action) =>
      _changes.containsKey(action) ? _changes[action] : defaults[action];

  /// The key's name for a tooltip or a menu, or null when there is none.
  String? keyLabel(ShortcutAction action) => bindingFor(action)?.label;

  /// " (Space)" to tack onto a tooltip, or nothing when the action has no key.
  String hint(ShortcutAction action) {
    final label = keyLabel(action);
    return label == null ? '' : ' ($label)';
  }

  /// What a key press asks for, if anything.
  ShortcutAction? actionFor(KeyEvent event) {
    for (final action in ShortcutAction.values) {
      if (bindingFor(action)?.matches(event) ?? false) return action;
    }
    return null;
  }

  /// The action already using [binding], other than [except].
  ShortcutAction? actionUsing(KeyBinding binding, {ShortcutAction? except}) {
    for (final action in ShortcutAction.values) {
      if (action != except && bindingFor(action) == binding) return action;
    }
    return null;
  }

  bool isDefault(ShortcutAction action) =>
      bindingFor(action) == defaults[action];

  bool get allDefault => ShortcutAction.values.every(isDefault);

  ShortcutMap withBinding(ShortcutAction action, KeyBinding? binding) {
    final changes = Map.of(_changes);
    if (binding == defaults[action]) {
      changes.remove(action);
    } else {
      changes[action] = binding;
    }
    return ShortcutMap(changes);
  }

  ShortcutMap reset(ShortcutAction action) =>
      withBinding(action, defaults[action]);

  static const ShortcutMap standard = ShortcutMap();

  String toJson() => jsonEncode({
    for (final MapEntry(:key, :value) in _changes.entries)
      key.name: value?.toJson(),
  });

  static ShortcutMap fromJson(String? json) {
    if (json == null || json.isEmpty) return standard;
    try {
      final raw = jsonDecode(json);
      if (raw is! Map) return standard;
      final changes = <ShortcutAction, KeyBinding?>{};
      for (final MapEntry(:key, :value) in raw.entries) {
        final action = ShortcutAction.values.cast<ShortcutAction?>().firstWhere(
          (a) => a!.name == key,
          orElse: () => null,
        );
        if (action == null) continue;
        changes[action] = value == null ? null : KeyBinding.fromJson(value);
      }
      return ShortcutMap(changes);
    } catch (_) {
      return standard;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutMap &&
      ShortcutAction.values.every((a) => a.bindingFor(other) == bindingFor(a));

  @override
  int get hashCode => Object.hashAll(ShortcutAction.values.map(bindingFor));
}

extension on ShortcutAction {
  KeyBinding? bindingFor(ShortcutMap map) => map.bindingFor(this);
}
