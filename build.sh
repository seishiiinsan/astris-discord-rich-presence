#!/bin/bash
# Build AstrisRPC.app (menu bar, no Dock icon) into ./build
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64
APP=build/AstrisRPC.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/AstrisRPC "$APP/Contents/MacOS/AstrisRPC"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AstrisRPC</string>
    <key>CFBundleDisplayName</key><string>Astris RPC</string>
    <key>CFBundleIdentifier</key><string>com.seishin.astris-rpc</string>
    <key>CFBundleExecutable</key><string>AstrisRPC</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "OK: $APP  (copie dans /Applications : cp -R $APP /Applications/)"
