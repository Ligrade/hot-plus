#!/bin/bash
# Compile Hot + et produit build/Hot +.app (signature ad hoc). Sans Xcode ouvert.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Hot +.app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/HotPlus"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HotPlus"
swift scripts/make_icon.swift "$PWD/$APP/Contents/Resources/AppIcon.icns"
rm -f "$APP/Contents/Resources/AppIcon.icns.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Hot +</string>
  <key>CFBundleDisplayName</key><string>Hot +</string>
  <key>CFBundleIdentifier</key><string>fr.ligrade.hotplus</string>
  <key>CFBundleExecutable</key><string>HotPlus</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Open source, by Ligrade</string>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
echo "OK → $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x HotPlus 2>/dev/null || true
  rm -rf "/Applications/Hot +.app"
  cp -R "$APP" "/Applications/Hot +.app"
  echo "Installé → /Applications/Hot +.app"
fi
