# Music Teleprompter — Installation Guide

## System Requirements
- macOS 10.15 (Catalina) or later
- Microphone access
- ~50MB disk space

---

## Install from DMG

1. Open `MusicTeleprompter.dmg`
2. Drag **Music Teleprompter** into your **Applications** folder
3. Eject the DMG

## First Launch (Important)

Because the app is not signed with an Apple Developer certificate, macOS will block it on first open.

**Do this:**
1. Go to **Applications**
2. **Right-click** (or Ctrl+click) the app icon
3. Select **Open**
4. Click **Open** in the security dialog

You only need to do this once.

## Grant Microphone Access

On first launch, macOS will ask:

> "Music Teleprompter would like to access the microphone"

Click **OK**. The app needs this to detect your beat and voice for scroll sync.

If you accidentally denied it:
1. Open **System Settings → Privacy & Security → Microphone**
2. Enable the toggle next to **Music Teleprompter**

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `SPACE` | Play / Pause |
| `↑` | Speed up scroll |
| `↓` | Slow down scroll |
| `→` | Jump to next section |
| `←` | Jump to previous section |
| `F` | Toggle fullscreen |
| `M` | Toggle mirror mode |
| `R` | Reset to start |
| `L` | Toggle loop mode |
| `ESC` | Back to editor |

---

## Script Format

```
[Intro | 4 bars]

Your first lyric line
Your second lyric line

[Verse 1]

More lyrics here
Keep going

[Chorus]

The big moment
Sing it loud
```

Sections use `[Name]` or `[Name | N bars]` format.
LRC timestamped files (`.lrc`) are also supported.

---

## Build from Source

Requires macOS + Flutter 3.x + Xcode

```bash
git clone <repo>
cd music_teleprompter
flutter pub get
flutter build macos --release
```

To create a DMG:
```bash
brew install create-dmg
chmod +x scripts/build_and_package.sh
./scripts/build_and_package.sh
```
