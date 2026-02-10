#!/usr/bin/env bash
set -euo pipefail

DEBUG_REMIND_NOW=false
for arg in "$@"; do
  case "$arg" in
    --debug)
      DEBUG_REMIND_NOW=true
      ;;
    --help|-h)
      echo "Usage: ./scripts/run-app.sh [--debug]"
      echo "  --debug   Show the 'Remind Now' debug button in the menu."
      exit 0
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Move Now.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUNDLE_ID="com.melodicdev.movenow"
BUILD_NUMBER="$(date +%s)"
DEBUG_PLIST_BOOL="<false/>"
if [ "$DEBUG_REMIND_NOW" = true ]; then
  DEBUG_PLIST_BOOL="<true/>"
fi

cd "$ROOT_DIR"
swift build

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/debug/MoveNow" "$MACOS_DIR/MoveNow"
chmod +x "$MACOS_DIR/MoveNow"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Sources/MoveNow/Resources/MoveNowIcon.png" "$RESOURCES_DIR/MoveNowIcon.png"
cp "$ROOT_DIR/Sources/MoveNow/Resources/MoveNowStatusIcon.png" "$RESOURCES_DIR/MoveNowStatusIcon.png"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MoveNow</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>Move Now</string>
    <key>NSApplicationIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>MoveNowDebugRemindNow</key>
    ${DEBUG_PLIST_BOOL}
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign the app so macOS treats it as a real bundle identity.
codesign --force --deep --sign - "$APP_DIR"

# Ensure old instances don't keep stale icon metadata/state around.
killall MoveNow >/dev/null 2>&1 || true

# LaunchServices registration can lag; opening the bundle helps register it.
open -n "$APP_DIR"

echo "Launched: $APP_DIR"
echo "Bundle ID: $BUNDLE_ID"
