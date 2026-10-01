#!/usr/bin/env bash
# Sends one file (a zipped .app or a .dmg) to Apple and waits for the verdict.
# A rejection prints Apple's own log, which says exactly which binary was at
# fault — without it, notarization failures are a guessing game.
#
# Needs APPLE_ID, APPLE_APP_PASSWORD and APPLE_TEAM_ID in the environment.
set -euo pipefail

FILE="$1"
echo "Notarizing $(basename "$FILE")…"

RESULT=$(xcrun notarytool submit "$FILE" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait --timeout 30m --output-format json)
echo "$RESULT"

read -r ID STATUS <<<"$(printf '%s' "$RESULT" | python3 -c "
import json, sys
r = json.load(sys.stdin)
print(r.get('id', ''), r.get('status', 'Unknown'))
")"

if [ "$STATUS" != "Accepted" ]; then
  echo "::error::Apple rejected $(basename "$FILE") ($STATUS). Its log:"
  [ -n "$ID" ] && xcrun notarytool log "$ID" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" || true
  exit 1
fi

echo "Accepted."
