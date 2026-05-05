# Music Teleprompter — Master Build Plan
**Last Updated:** 2026-05-03  
**Status:** Phase 1 — Project Setup

---

## Project Overview

A professional macOS teleprompter app for music performance (lyrics for vocalists, DJs, live performers). Offline-first, distributable as a signed/unsigned .app and .dmg installer. Built with Flutter (Dart) + native Swift bridge for audio.

---

## Architecture

```
music_teleprompter/
├── lib/
│   ├── main.dart                        # App entry, window config
│   ├── app.dart                         # MaterialApp, theme, routing
│   ├── models/
│   │   ├── script_line.dart             # ScriptLine {text, timestamp, beatIndex, words[]}
│   │   ├── script_section.dart          # ScriptSection {label, lines[], barCount}
│   │   └── script.dart                  # Script {title, sections[], rawText}
│   ├── engine/
│   │   ├── sync_engine.dart             # SyncEngine (central controller)
│   │   ├── audio_engine.dart            # Mic capture + beat detection
│   │   ├── voice_detection_layer.dart   # Voice presence detection
│   │   └── scroll_engine.dart           # Custom 60fps scroll animator
│   ├── services/
│   │   ├── script_parser.dart           # Parses raw lyrics into Script model
│   │   ├── audio_permission_service.dart# Requests/checks mic permission
│   │   └── file_service.dart            # Load/save .txt/.lrc script files
│   ├── views/
│   │   ├── home_view.dart               # Landing page (recent scripts, open)
│   │   ├── editor_view.dart             # Script editor with section tags
│   │   ├── teleprompter_view.dart       # Fullscreen performance view
│   │   └── settings_view.dart           # Font size, scroll speed, theme prefs
│   ├── widgets/
│   │   ├── script_line_widget.dart      # Single lyric line (highlight, karaoke)
│   │   ├── controls_overlay.dart        # Play/pause, speed, BPM, loop
│   │   ├── mirror_transform.dart        # Horizontal flip wrapper
│   │   └── section_header_widget.dart  # [Chorus | 4 bars] display
│   └── utils/
│       ├── keyboard_handler.dart        # SPACE/UP/DOWN/LEFT/RIGHT bindings
│       └── constants.dart               # App-wide constants
├── macos/
│   ├── Runner/
│   │   ├── Info.plist                   # NSMicrophoneUsageDescription
│   │   └── DebugProfile.entitlements    # com.apple.security.device.audio-input
│   │   └── Release.entitlements         # com.apple.security.device.audio-input
│   └── Podfile
├── assets/
│   ├── scripts/                         # Bundled example lyrics
│   └── fonts/                           # Custom display fonts
├── scripts/
│   └── build_and_package.sh            # Build .app + create .dmg
├── PLAN.md                              # This file
├── INSTALL.md                           # User installation guide
└── pubspec.yaml
```

---

## Tech Stack

| Layer              | Technology                              |
|--------------------|-----------------------------------------|
| UI Framework       | Flutter 3.x (macOS desktop)             |
| Language           | Dart 3.x                                |
| Audio Capture      | `record` package (mic stream)           |
| Beat Detection     | `aubio` via FFI or native Swift plugin  |
| Voice Detection    | WebRTC VAD (via `dart_webrtc` or Swift) |
| State Management   | Riverpod (providers for engine state)   |
| File I/O           | `file_picker` + `path_provider`         |
| Windowing          | `window_manager` package                |
| Permissions        | `permission_handler` or native          |
| Packaging          | `create-dmg` (Homebrew)                 |

---

## Phase Breakdown

### PHASE 1 — Project Foundation
- [ ] 1.1 Create Flutter macOS project (`flutter create --platforms=macos music_teleprompter`)
- [ ] 1.2 Configure `pubspec.yaml` with all dependencies
- [ ] 1.3 Configure `macos/Runner/Info.plist` — `NSMicrophoneUsageDescription`
- [ ] 1.4 Configure `macos/Runner/*.entitlements` — audio-input entitlement
- [ ] 1.5 Set up folder structure (models, engine, services, views, widgets, utils)
- [ ] 1.6 Configure `window_manager` for custom macOS window (titlebar, fullscreen)
- [ ] 1.7 Set up Riverpod provider structure

### PHASE 2 — Data Models & Script System
- [ ] 2.1 `ScriptLine` model — text, timestamp?, beatIndex?, words[]
- [ ] 2.2 `ScriptSection` model — label, lines[], barCount?
- [ ] 2.3 `Script` model — title, sections[], rawText
- [ ] 2.4 `ScriptParser` — parses `[Tag | N bars]` syntax into sections
- [ ] 2.5 `FileService` — open/save .txt and .lrc files via file_picker
- [ ] 2.6 Example bundled scripts (assets/scripts/)

### PHASE 3 — Audio Engine
- [ ] 3.1 `AudioEngine` — mic capture via `record` package
- [ ] 3.2 Beat detection integration (aubio FFI or Swift native plugin)
- [ ] 3.3 BPM estimator (rolling average over last 8 beats)
- [ ] 3.4 Beat event stream (`Stream<BeatEvent>`)
- [ ] 3.5 `AudioPermissionService` — runtime mic permission request on first launch

### PHASE 4 — Voice Detection Layer
- [ ] 4.1 `VoiceDetectionLayer` — WebRTC VAD or energy threshold fallback
- [ ] 4.2 Voice presence stream (`Stream<bool>`)
- [ ] 4.3 Debounce logic (avoid flapping on short silences)
- [ ] 4.4 Configurable sensitivity threshold

### PHASE 5 — Sync Engine
- [ ] 5.1 `SyncEngine` central controller
- [ ] 5.2 `updateFromBeat()` — adjust scroll speed from BPM
- [ ] 5.3 `updateFromVoice()` — speed up (voice active) / slow/pause (silence)
- [ ] 5.4 `computeScrollSpeed()` — weighted combination of BPM + voice + manual
- [ ] 5.5 Manual speed override (slider 0.1x – 5.0x)
- [ ] 5.6 Smooth speed transitions (no abrupt jumps)

### PHASE 6 — Scroll Engine
- [ ] 6.1 `ScrollEngine` — custom `AnimationController`-based scroll (no ListView)
- [ ] 6.2 60fps tick loop via `Ticker`
- [ ] 6.3 GPU acceleration via `RepaintBoundary` + `Transform`
- [ ] 6.4 Position clamping (stop at first/last line)
- [ ] 6.5 Jump-to-line (LEFT/RIGHT keyboard)
- [ ] 6.6 Easing curves for acceleration/deceleration

### PHASE 7 — Teleprompter UI
- [ ] 7.1 `TeleprompterView` — fullscreen dark canvas
- [ ] 7.2 `ScriptLineWidget` — center-aligned, variable font size
- [ ] 7.3 Active line highlight (color + scale pulse)
- [ ] 7.4 Karaoke word-highlight (word-by-word timing)
- [ ] 7.5 `SectionHeaderWidget` — [Chorus | 4 bars] display
- [ ] 7.6 `ControlsOverlay` — auto-hide, shows on mouse move
- [ ] 7.7 `MirrorTransform` — horizontal flip for teleprompter glass
- [ ] 7.8 Font size control (pinch-to-zoom or +/- keys)

### PHASE 8 — Editor View
- [ ] 8.1 `EditorView` — multi-line text editor
- [ ] 8.2 Section tag syntax highlighting
- [ ] 8.3 Preview panel (split view)
- [ ] 8.4 Load from file / paste from clipboard
- [ ] 8.5 Auto-save to local storage

### PHASE 9 — Controls & Keyboard
- [ ] 9.1 `KeyboardHandler` — global key listener
- [ ] 9.2 SPACE → Play/Pause
- [ ] 9.3 UP → Speed +0.1
- [ ] 9.4 DOWN → Speed -0.1
- [ ] 9.5 LEFT → Jump to previous section
- [ ] 9.6 RIGHT → Jump to next section
- [ ] 9.7 F → Toggle fullscreen
- [ ] 9.8 M → Toggle mirror mode
- [ ] 9.9 ESC → Exit fullscreen / back to editor

### PHASE 10 — Features
- [ ] 10.1 Loop mode — define loop start/end line, auto-repeat
- [ ] 10.2 Mirror mode — `Transform.scale(scaleX: -1)` wrapper
- [ ] 10.3 Karaoke highlight — word-level timing via LRC format or beat-sync
- [ ] 10.4 Manual scroll override — drag scroll position

### PHASE 11 — Settings
- [ ] 11.1 `SettingsView` — font size, scroll speed default, theme color
- [ ] 11.2 Persist settings via `shared_preferences`
- [ ] 11.3 Voice detection sensitivity slider
- [ ] 11.4 BPM override (manual input)

### PHASE 12 — Build & Packaging
- [ ] 12.1 `flutter build macos --release`
- [ ] 12.2 Verify .app output in `build/macos/Build/Products/Release/`
- [ ] 12.3 Install `create-dmg` via Homebrew
- [ ] 12.4 Create `scripts/build_and_package.sh`
- [ ] 12.5 Generate `MusicTeleprompter.dmg`
- [ ] 12.6 Test DMG install flow (drag to Applications, launch)

### PHASE 13 — QA & Polish
- [ ] 13.1 Test: singing voice detection accuracy
- [ ] 13.2 Test: BPM detection with various tempos (60–180 BPM)
- [ ] 13.3 Test: scroll smoothness (no jitter at 60fps)
- [ ] 13.4 Test: silence detection → scroll pause
- [ ] 13.5 Test: keyboard shortcuts in fullscreen
- [ ] 13.6 Test: DMG installation on clean macOS
- [ ] 13.7 Test: microphone permission prompt

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  record: ^5.0.0              # Mic capture
  permission_handler: ^11.0.0 # Runtime mic permission
  window_manager: ^0.3.8      # macOS window control
  file_picker: ^6.1.0         # Open/save script files
  path_provider: ^2.1.0       # Local storage paths
  shared_preferences: ^2.2.0  # Persist settings

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

---

## macOS Info.plist Keys Required

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Music Teleprompter uses your microphone to detect beat and vocal presence for automatic scroll sync.</string>
```

## macOS Entitlements Required

```xml
<!-- Both DebugProfile.entitlements and Release.entitlements -->
<key>com.apple.security.device.audio-input</key>
<true/>
```

---

## Build & Package Script

```bash
#!/bin/bash
# scripts/build_and_package.sh

flutter build macos --release

create-dmg \
  --volname "Music Teleprompter" \
  --volicon "assets/icons/app_icon.icns" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "Music Teleprompter.app" 200 185 \
  --hide-extension "Music Teleprompter.app" \
  --app-drop-link 600 185 \
  "MusicTeleprompter.dmg" \
  "build/macos/Build/Products/Release/"
```

---

## SyncEngine Interface

```dart
class SyncEngine extends ChangeNotifier {
  double bpm = 120.0;
  bool isVoiceActive = false;
  double scrollSpeed = 1.0;       // pixels per frame
  double manualMultiplier = 1.0;  // 0.1x – 5.0x from slider

  void updateFromBeat(BeatEvent event);
  void updateFromVoice(bool voiceDetected);
  double computeScrollSpeed();
  void pause();
  void resume();
}
```

---

## ScriptLine Model

```dart
class ScriptLine {
  final String text;
  final List<String> words;
  final double? timestamp;     // seconds from start
  final int? beatIndex;        // beat number this line starts on
  final bool isSectionHeader;
  final String? sectionLabel;
}
```

---

## Build Checklist (run before each release)

- [x] `flutter analyze` — zero warnings ✓ (2026-05-04)
- [x] `flutter test` — all tests pass ✓ 5/5 (2026-05-04)
- [ ] Mic permission prompt appears on first launch
- [ ] Beat detection produces BPM output
- [ ] Scroll starts/stops with voice
- [ ] Keyboard shortcuts work in fullscreen
- [ ] Mirror mode flips horizontally
- [ ] DMG installs and launches correctly
- [ ] App runs offline (no network calls)

---

## Current Status Log

| Date       | Phase | Status       | Notes                                                   |
|------------|-------|--------------|---------------------------------------------------------|
| 2026-05-03 | 0     | Done         | Master plan created, PLAN.md written                    |
| 2026-05-04 | 1–11  | Done         | Full Flutter project built. flutter analyze: 0 issues.  |
|            |       |              | flutter test: 5/5 pass. JetBrains Mono font added.      |
|            |       |              | Remaining: macOS build (requires Mac). Transfer project  |
|            |       |              | to Mac, run build_and_package.sh to produce .dmg        |
