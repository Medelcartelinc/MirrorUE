#!/usr/bin/env bash
# ==============================================================================
#  OmniMirror — 1-Click macOS App Installer (by Medelcartel)
#  Builds, packages, signs, and installs OmniMirror.app to /Applications
# ==============================================================================
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo -e "${BLUE}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║            🪞 OmniMirror macOS Installer          ║"
echo "  ║     Ultra-Low-Latency 120 FPS iPhone Mirroring    ║"
echo "  ║           Native Intel & Apple Silicon            ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${RESET}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# 1. Check prerequisites
echo -e "${CYAN}==> Checking prerequisites...${RESET}"
if ! command -v swift &>/dev/null; then
  echo -e "${YELLOW}Error: Xcode Command Line Tools or Swift not found.${RESET}"
  echo "Run: xcode-select --install"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo -e "${YELLOW}Error: python3 not found.${RESET}"
  exit 1
fi

echo -e "${GREEN}✓ Swift & Python3 ready${RESET}"

# 2. Build binaries (UI + Engine)
echo -e "\n${CYAN}==> Building Swift release binary (Optimized for Intel & Apple Silicon)...${RESET}"
swift build -c release --product OmniMirror
BIN_PATH="$(swift build -c release --show-bin-path)/OmniMirror"
mkdir -p bin
cp -f "$BIN_PATH" bin/OmniMirror
cp -f "$BIN_PATH" bin/MirrorUE

if [[ ! -f "bin/MirrorUEEngine" ]]; then
  echo -e "\n${CYAN}==> Freezing CoreDevice engine binary...${RESET}"
  ./tools/build_engine.sh
fi
echo -e "${GREEN}✓ Binaries ready: bin/OmniMirror & bin/MirrorUEEngine${RESET}"

# 3. Create .app Bundle structure
echo -e "\n${CYAN}==> Creating OmniMirror.app Bundle...${RESET}"
APP_BUNDLE="dist/OmniMirror.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy UI & Engine executables
cp -f "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/OmniMirror"
chmod +x "$APP_BUNDLE/Contents/MacOS/OmniMirror"

if [[ -f "bin/MirrorUEEngine" ]]; then
  cp -f "bin/MirrorUEEngine" "$APP_BUNDLE/Contents/MacOS/MirrorUEEngine"
  chmod +x "$APP_BUNDLE/Contents/MacOS/MirrorUEEngine"
fi

# Copy AppIcon
if [[ -f "dist/AppIcon.icns" ]]; then
  cp -f "dist/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Generate Info.plist
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>OmniMirror</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>com.medelcartel.omnimirror</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>OmniMirror</string>
  <key>CFBundleDisplayName</key><string>OmniMirror</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key>
  <string>OmniMirror needs camera permission to capture your iPhone screen at up to 120 FPS via CoreMediaIO.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>OmniMirror needs microphone permission to stream your iPhone audio directly to your Mac speakers in real time.</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

echo -e "\n${CYAN}==> Signing OmniMirror with entitlements...${RESET}"
xattr -cr "$APP_BUNDLE"
security unlock-keychain -p omnibar-signing "$HOME/Library/Keychains/omnibar-signing.keychain-db" 2>/dev/null || true
if security find-certificate -c "OmniBar Signing" >/dev/null 2>&1; then
  codesign --force --deep --sign "OmniBar Signing" --entitlements "$ROOT/MirrorUE.entitlements" "$APP_BUNDLE"
  echo -e "${GREEN}✓ App signed with stable identity (OmniBar Signing)${RESET}"
else
  codesign --force --deep --sign - --entitlements "$ROOT/MirrorUE.entitlements" "$APP_BUNDLE"
  echo -e "${GREEN}✓ App signed ad-hoc${RESET}"
fi

# Also mirror bundle as MirrorUE.app for backwards compatibility
rm -rf dist/MirrorUE.app
cp -R "$APP_BUNDLE" dist/MirrorUE.app

# 5. Install to Applications
echo -e "\n${CYAN}==> Installing to Applications...${RESET}"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/OmniMirror.app"
cp -R "$APP_BUNDLE" "$HOME/Applications/"
echo -e "${GREEN}✓ Installed to $HOME/Applications/OmniMirror.app${RESET}"

if cp -R "$APP_BUNDLE" "/Applications/" 2>/dev/null; then
  echo -e "${GREEN}✓ Also installed to system /Applications/OmniMirror.app${RESET}"
fi

# 6. Create CLI shortcuts
mkdir -p "$HOME/.local/bin"
ln -sf "$ROOT/bin/OmniMirror" "$HOME/.local/bin/omnimirror"
ln -sf "$ROOT/bin/MirrorUE" "$HOME/.local/bin/mirrorue"
if [[ -w "/usr/local/bin" ]]; then
  ln -sf "$ROOT/bin/OmniMirror" "/usr/local/bin/omnimirror" 2>/dev/null || true
  ln -sf "$ROOT/bin/MirrorUE" "/usr/local/bin/mirrorue" 2>/dev/null || true
fi
echo -e "${GREEN}✓ CLI shortcuts created: omnimirror & mirrorue${RESET}"

echo -e "\n${GREEN}${BOLD}═══════════════════════════════════════════════════"
echo "  🎉 Installation Complete!"
echo "═══════════════════════════════════════════════════${RESET}"
echo -e "You can launch OmniMirror by:"
echo -e "  1. Opening ${BOLD}OmniMirror${RESET} from ${BOLD}Spotlight${RESET} (⌘ + Space) or ${BOLD}Applications${RESET}"
echo -e "  2. Running ${CYAN}open /Applications/OmniMirror.app${RESET}"
echo -e "  3. Running ${CYAN}omnimirror${RESET} in Terminal"
echo ""
