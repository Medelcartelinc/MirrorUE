#!/bin/bash
# ==============================================================================
#  OmniMirror — DMG & Release Archive Packager
# ==============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="OmniMirror"
APP="dist/$APP_NAME.app"
VOLUME="$APP_NAME"
VERSION="1.0.0"
DMG_OUT="dist/OmniMirror-${VERSION}-Intel.dmg"
ZIP_OUT="dist/OmniMirror-v${VERSION}-macOS-Intel.zip"

if [[ ! -d "$APP" ]]; then
  echo "==> $APP not found. Running ./install.sh..."
  ./install.sh
fi

echo "==> Verifying signatures and entitlements..."
xattr -cr "$APP"
security unlock-keychain -p omnibar-signing "$HOME/Library/Keychains/omnibar-signing.keychain-db" 2>/dev/null || true
if security find-certificate -c "OmniBar Signing" >/dev/null 2>&1; then
  codesign --force --deep --sign "OmniBar Signing" --entitlements "$ROOT/MirrorUE.entitlements" "$APP"
  echo "✓ Signed with OmniBar Signing"
else
  codesign --force --deep --sign - --entitlements "$ROOT/MirrorUE.entitlements" "$APP"
  echo "✓ Signed ad-hoc"
fi
codesign --verify --deep --strict "$APP"

echo "==> Staging DMG..."
STAGING="$(mktemp -d)"
WORK="$(mktemp -d)"
RW="$WORK/rw.dmg"

cleanup() {
  if [[ -n "${MOUNT:-}" ]]; then
    hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true
  fi
  rm -rf "$STAGING" "$WORK"
}
trap cleanup EXIT

ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating writable disk image..."
hdiutil detach "/Volumes/$VOLUME" -force 2>/dev/null || true
hdiutil create -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW" -quiet

ATTACH_OUTPUT="$(hdiutil attach "$RW" -nobrowse)"
MOUNT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

echo "==> Arranging DMG layout..."
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$VOLUME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {250, 150, 750, 500}
        set theOptions to the icon view options of container window
        set arrangement of theOptions to not arranged
        set icon size of theOptions to 128
        set text size of theOptions to 13
        set position of item "$APP_NAME.app" of container window to {140, 180}
        set position of item "Applications" of container window to {360, 180}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true
MOUNT=""

echo "==> Compressing to UDZO DMG..."
rm -f "$DMG_OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" -quiet

echo "==> Creating ZIP distribution..."
rm -f "$ZIP_OUT"
ditto -c -k --keepParent "$APP" "$ZIP_OUT"

echo "✓ Created: $DMG_OUT"
echo "✓ Created: $ZIP_OUT"
ls -lh "$DMG_OUT" "$ZIP_OUT"
