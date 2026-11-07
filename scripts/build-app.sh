#!/bin/bash
# リリース版をビルドし、build/Menu Bar Cleaner.app を作る。
# 署名はアドホック署名（-）。配布用の署名と公証はしていない。
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/MenuBarCleaner"

APP="build/Menu Bar Cleaner.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/MenuBarCleaner"
codesign --force --sign - "$APP"

echo "作成しました：$APP"
