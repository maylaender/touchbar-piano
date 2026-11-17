#!/bin/sh
# Builds Piano.app (universal: Intel + Apple Silicon). Requires Xcode Command Line Tools.
set -e
APP=Piano.app
rm -rf "$APP" build && mkdir -p "$APP/Contents/MacOS" build
swiftc -O -target x86_64-apple-macos10.15 main.swift -o build/Piano-x86_64
swiftc -O -target arm64-apple-macos11    main.swift -o build/Piano-arm64
lipo -create build/Piano-x86_64 build/Piano-arm64 -output "$APP/Contents/MacOS/Piano"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Piano</string>
  <key>CFBundleIdentifier</key><string>local.touchbar-piano</string>
  <key>CFBundleName</key><string>Touch Bar Piano</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force -s - "$APP"
echo "Built $APP"
