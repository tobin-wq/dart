#!/bin/bash
# Build, then install the stable-signed app to the location you actually run,
# and relaunch it. Use this instead of running Dart.app from Downloads.
set -euo pipefail
cd "$(dirname "$0")"

DEST="/Applications/Dart.app"

./build.sh

echo "Installing -> $DEST"
pkill -x Dart 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R Dart.app "$DEST"

open "$DEST"
sleep 1
echo "Installed and launched: $(ps -p "$(pgrep -x Dart)" -o comm= 2>/dev/null)"
