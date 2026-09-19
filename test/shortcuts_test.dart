import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/models/shortcuts.dart';
import 'package:music_teleprompter/utils/keyboard_handler.dart';

/// Keys on the song screen are the user's to choose, and can always go
/// back to the defaults.
void main() {
  group('ShortcutMap', () {
    test('starts with the defaults and knows when they change', () {
      const map = ShortcutMap.standard;
      expect(map.allDefault, true);
      expect(map.keyLabel(ShortcutAction.playPause), 'Space');
      expect(map.keyLabel(ShortcutAction.speedUp), '+');
      expect(map.keyLabel(ShortcutAction.back), 'Esc');

      final changed = map.withBinding(
        ShortcutAction.playPause,
        const KeyBinding(LogicalKeyboardKey.keyK),
      );
      expect(changed.allDefault, false);
      expect(changed.isDefault(ShortcutAction.playPause), false);
      expect(changed.isDefault(ShortcutAction.speedUp), true);
      expect(changed.keyLabel(ShortcutAction.playPause), 'K');
      expect(changed.reset(ShortcutAction.playPause).allDefault, true);
    });

    test('a key can be taken away, and a clash is noticed', () {
      final map = ShortcutMap.standard.withBinding(ShortcutAction.mirror, null);
      expect(map.keyLabel(ShortcutAction.mirror), isNull);
      expect(map.hint(ShortcutAction.mirror), '');
      expect(map.hint(ShortcutAction.edit), ' (E)');

      expect(
        map.actionUsing(const KeyBinding(LogicalKeyboardKey.keyN)),
        ShortcutAction.nextSong,
      );
      expect(
        map.actionUsing(
          const KeyBinding(LogicalKeyboardKey.keyN),
          except: ShortcutAction.nextSong,
        ),
        isNull,
      );
      expect(
        map.actionUsing(const KeyBinding(LogicalKeyboardKey.keyK)),
        isNull,
      );
    });

    test('only the changes are saved, and they come back', () {
      final map = ShortcutMap.standard
          .withBinding(
            ShortcutAction.playPause,
            const KeyBinding(LogicalKeyboardKey.keyK, control: true),
          )
          .withBinding(ShortcutAction.mirror, null);
      final json = map.toJson();
      expect(json, contains('playPause'));
      expect(json, isNot(contains('speedUp')));

      final back = ShortcutMap.fromJson(json);
      expect(back, map);
      expect(back.keyLabel(ShortcutAction.playPause), 'Ctrl+K');
      expect(back.bindingFor(ShortcutAction.mirror), isNull);
      expect(back.keyLabel(ShortcutAction.speedUp), '+');

      expect(ShortcutMap.fromJson(null), ShortcutMap.standard);
      expect(ShortcutMap.fromJson('not json'), ShortcutMap.standard);
    });

    test('numpad keys count as their main-keyboard twins', () {
      expect(
        KeyBinding.normalise(LogicalKeyboardKey.numpadAdd),
        LogicalKeyboardKey.equal,
      );
      expect(
        KeyBinding.normalise(LogicalKeyboardKey.numpadEnter),
        LogicalKeyboardKey.enter,
      );
      expect(KeyBinding.isPedalKey(LogicalKeyboardKey.numpadEnter), true);
      expect(KeyBinding.isPedalKey(LogicalKeyboardKey.keyK), false);
      expect(KeyBinding.isModifier(LogicalKeyboardKey.shiftLeft), true);
    });
  });

  group('On the song screen', () {
    late List<String> calls;

    Future<void> pumpHandler(WidgetTester tester, ShortcutMap shortcuts) async {
      calls = [];
      final sync = SyncEngine();
      await tester.pumpWidget(
        MaterialApp(
          home: TeleprompterKeyboardHandler(
            syncEngine: sync,
            scrollEngine: ScrollEngine(syncEngine: sync),
            shortcuts: shortcuts,
            onToggleFullscreen: () => calls.add('fullscreen'),
            onBack: () => calls.add('back'),
            onNextScript: () => calls.add('nextSong'),
            onPrevScript: () => calls.add('prevSong'),
            onPlayPauseOverride: () => calls.add('playPause'),
            onToggleMirror: () => calls.add('mirror'),
            onEdit: () => calls.add('edit'),
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the defaults work as printed', (tester) async {
      await pumpHandler(tester, ShortcutMap.standard);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(calls, ['playPause', 'nextSong', 'edit', 'back']);
    });

    testWidgets('the user\'s keys replace the defaults', (tester) async {
      final custom = ShortcutMap.standard
          .withBinding(
            ShortcutAction.playPause,
            const KeyBinding(LogicalKeyboardKey.keyK),
          )
          .withBinding(
            ShortcutAction.nextSong,
            const KeyBinding(LogicalKeyboardKey.keyN, shift: true),
          )
          .withBinding(ShortcutAction.edit, null);
      await pumpHandler(tester, custom);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyEvent(LogicalKeyboardKey.space); // no longer bound
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE); // taken away
      expect(calls, ['playPause']);

      // N alone is nothing now; Shift+N is next song
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      expect(calls, ['playPause']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(calls, ['playPause', 'nextSong']);
    });

    testWidgets('foot pedal keys keep working whatever the shortcuts', (
      tester,
    ) async {
      final custom = ShortcutMap.standard.withBinding(
        ShortcutAction.playPause,
        const KeyBinding(LogicalKeyboardKey.keyK),
      );
      await pumpHandler(tester, custom);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      expect(calls, isEmpty); // the default pedal action is section jumps
    });
  });
}
