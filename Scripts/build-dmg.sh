#!/bin/bash
# Build a signed Tinycast.app into build/Tinycast-<version>.dmg. Usage: ./Scripts/build-dmg.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
IDENTITY="$(security find-identity -p codesigning | awk '/"Tinycast Self-Signed"/ {print $2; exit}')"
DERIVED="build/DerivedData"

if [ -z "$IDENTITY" ]; then
    echo "✗ Tinycast Self-Signed identity not found — see docs/signing.md." >&2
    exit 1
fi

echo "▸ Building signed Tinycast.app (Release)…"
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
    ${1:+MARKETING_VERSION="$1"} \
    build

APP="$DERIVED/Build/Products/Release/Tinycast.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Tinycast-${VERSION}.dmg"

echo "▸ Packaging ${DMG}"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
diskutil image create from "$STAGE" --format UDZO --volumeName "Tinycast" "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ $DMG"