#!/bin/bash
# Build the Swift helpers from the repo's config/sketchybar/helper sources.
# Output goes next to the sources; copy the ones you need into the live config.
set -euo pipefail
cd "$(dirname "$0")/../config/sketchybar/helper"

command -v swiftc >/dev/null || { echo "swiftc not found; install Xcode Command Line Tools"; exit 1; }

for f in *.swift; do
  n="${f%.swift}"
  [ "$n" = "wifiscan" ] && continue
  echo "build $n"
  swiftc -target arm64-apple-macos14.0 -O "$f" -o "$n"
done

# Wi-Fi scan needs Location permission, which macOS grants to app bundles.
APP="WifiScan.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
echo "build $APP"
swiftc -target arm64-apple-macos14.0 -O wifiscan.swift -o "$APP/Contents/MacOS/WifiScan"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.sketchybar.wifiscan</string>
  <key>CFBundleName</key><string>SketchyBar Wi-Fi Scan</string>
  <key>CFBundleDisplayName</key><string>SketchyBar Wi-Fi Scan</string>
  <key>CFBundleExecutable</key><string>WifiScan</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSLocationUsageDescription</key><string>Reads nearby Wi-Fi names so the SketchyBar Wi-Fi popup can list saved networks in range. Location is never stored or sent.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>Reads nearby Wi-Fi names so the SketchyBar Wi-Fi popup can list saved networks in range. Location is never stored or sent.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "done"
