#!/bin/bash
set -e

APP_NAME="Music Teleprompter"
DMG_NAME="MusicTeleprompter"
BUILD_DIR="build/macos/Build/Products/Release"

echo "========================================"
echo "  Music Teleprompter — Build & Package"
echo "========================================"

# Step 1: Flutter build
echo ""
echo "[1/3] Building macOS release app..."
flutter build macos --release

APP_PATH="$BUILD_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: Build failed — .app not found at $APP_PATH"
  exit 1
fi

echo "  ✓ Built: $APP_PATH"

# Step 2: Verify create-dmg
echo ""
echo "[2/3] Checking create-dmg..."
if ! command -v create-dmg &>/dev/null; then
  echo "  create-dmg not found. Installing via Homebrew..."
  brew install create-dmg
fi

# Step 3: Create DMG
echo ""
echo "[3/3] Creating DMG installer..."

OUTPUT_DMG="$DMG_NAME.dmg"

if [ -f "$OUTPUT_DMG" ]; then
  rm "$OUTPUT_DMG"
fi

create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 200 185 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 600 185 \
  --background "" \
  "$OUTPUT_DMG" \
  "$BUILD_DIR/"

echo ""
echo "========================================"
echo "  Done!"
echo "  DMG: $OUTPUT_DMG"
echo ""
echo "  DISTRIBUTION NOTES:"
echo "  • Right-click app → Open on first launch (unsigned)"
echo "  • For wider distribution: sign + notarize with Apple Developer account"
echo "========================================"
