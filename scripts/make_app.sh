#!/usr/bin/env bash
# Assembles EyeBreak.app from the SwiftPM release binary (PRD §8.1 / US-13).
# Usage: scripts/make_app.sh [output-dir]   (default: ./dist)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"
VERSION="0.1.0"
APP="$OUT_DIR/EyeBreak.app"

echo "==> Building release binary"
swift build -c release --package-path "$REPO_ROOT"
BIN="$(swift build -c release --package-path "$REPO_ROOT" --show-bin-path)/EyeBreak"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

sed "s/__VERSION__/$VERSION/g" "$REPO_ROOT/Resources/Info.plist.template" \
    > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$BIN" "$APP/Contents/MacOS/EyeBreak"

# Ad-hoc signature so SMAppService (launch at login) and TCC behave.
echo "==> Ad-hoc code signing"
codesign --force --sign - "$APP"

echo "==> Done: $APP"
echo "    Drag it into /Applications, or: open \"$APP\""
