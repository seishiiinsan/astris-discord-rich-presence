#!/bin/bash
# Build AstrisRPC.app (menu bar, no Dock icon) into ./build
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0.0}"

swift build -c release --arch arm64
APP=build/AstrisRPC.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN="$(swift build -c release --arch arm64 --show-bin-path)/AstrisRPC"
cp "$BIN" "$APP/Contents/MacOS/AstrisRPC"

# Icon: Resources/AppIcon.png (1024px) -> AppIcon.icns
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>AstrisRPC</string>
    <key>CFBundleDisplayName</key><string>Astris RPC</string>
    <key>CFBundleIdentifier</key><string>com.seishin.astris-rpc</string>
    <key>CFBundleExecutable</key><string>AstrisRPC</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "OK: $APP  (copie dans /Applications : cp -R $APP /Applications/)"
