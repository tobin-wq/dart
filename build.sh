#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Dart"
APP="$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_SRC="AppIcon.png"
ARCH="$(uname -m)"
SDK="$(xcrun --show-sdk-path)"

echo "Building $APP for $ARCH ..."

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp Info.plist "$CONTENTS/Info.plist"

# Generate a multi-resolution app icon (.icns) from the source PNG.
if [ -f "$ICON_SRC" ]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for spec in 16:16x16 32:16x16@2x 32:32x32 64:32x32@2x 128:128x128 256:128x128@2x 256:256x256 512:256x256@2x 512:512x512 1024:512x512@2x; do
        px="${spec%%:*}"; name="${spec##*:}"
        sips -z "$px" "$px" "$ICON_SRC" --out "$ICONSET/icon_${name}.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
    cp "$ICON_SRC" "$RESOURCES/AppIcon.png"   # transparent source for the runtime Dock icon
    echo "Icon generated -> $RESOURCES/AppIcon.icns (+ AppIcon.png)"
else
    echo "(no $ICON_SRC found — skipping icon)"
fi

xcrun swiftc \
    -sdk "$SDK" \
    -target "${ARCH}-apple-macosx13.0" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework ServiceManagement \
    -framework ApplicationServices \
    -o "$MACOS/$APP_NAME" \
    Sources/*.swift

# Sign with the STABLE self-signed identity if available (so the Accessibility
# permission survives rebuilds). Falls back to ad-hoc otherwise.
SIGN_ID="Dart Self Signed"
SIGN_KEYCHAIN="$HOME/Library/Keychains/dart-signing.keychain-db"
if [ -f "$SIGN_KEYCHAIN" ] && security find-identity -p codesigning "$SIGN_KEYCHAIN" 2>/dev/null | grep -q "$SIGN_ID"; then
    security unlock-keychain -p "dart-signing" "$SIGN_KEYCHAIN" 2>/dev/null || true
    codesign --force --sign "$SIGN_ID" --identifier com.local.dart "$APP"
    echo "Signed with stable identity: $SIGN_ID"
else
    codesign --force --sign - "$APP" >/dev/null 2>&1 || true
    echo "Signed ad-hoc (run ./setup-signing.sh once for a permanent Accessibility grant)."
fi

echo "Done -> $(pwd)/$APP"
