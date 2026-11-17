#!/bin/sh
# Builds Piano.app (universal: Intel + Apple Silicon). Requires Xcode Command Line Tools.
set -e
APP=Piano.app
rm -rf "$APP" build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset
swiftc -O -target x86_64-apple-macos10.15 main.swift -o build/Piano-x86_64
swiftc -O -target arm64-apple-macos11    main.swift -o build/Piano-arm64
lipo -create build/Piano-x86_64 build/Piano-arm64 -output "$APP/Contents/MacOS/Piano"
for s in 16 32 128 256 512; do
  sips -z $s $s icon.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) icon.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
VER=$(tr -d 'v \n' < VERSION)
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Piano</string>
  <key>CFBundleIdentifier</key><string>local.touchbar-piano</string>
  <key>CFBundleName</key><string>Touch Bar Piano</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VER</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force -s - "$APP"
echo "Built $APP"
