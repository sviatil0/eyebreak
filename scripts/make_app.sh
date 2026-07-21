#!/usr/bin/env bash
# Assembles EyeBreak.app from the SwiftPM release binary (PRD §8.1 / US-13).
# Usage: scripts/make_app.sh [output-dir]   (default: ./dist)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"
# Version comes from the newest CHANGELOG section unless overridden via env.
VERSION="${VERSION:-$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$REPO_ROOT/CHANGELOG.md" | sed -E 's/^## \[([0-9.]+)\].*/\1/')}"
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

echo "==> Packaging $OUT_DIR/EyeBreak-$VERSION.zip"
STAGE="$(mktemp -d)/EyeBreak"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
cp "$REPO_ROOT/Resources/INSTALL.txt" "$STAGE/INSTALL.txt"
rm -f "$OUT_DIR/EyeBreak-$VERSION.zip"
ditto -c -k --keepParent "$STAGE" "$OUT_DIR/EyeBreak-$VERSION.zip"
rm -rf "$(dirname "$STAGE")"

echo "==> Done: $APP  +  $OUT_DIR/EyeBreak-$VERSION.zip"
echo "    Drag the app into /Applications, or: open \"$APP\""
