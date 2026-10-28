#!/bin/bash
# Build AstrisRPC.app (menu bar, no Dock icon) into ./build
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${VERSION:-$(tr -d "[:space:]" < VERSION)}"
# "Developer ID Application: …" to sign for notarization; "-" (ad hoc) otherwise.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

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
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>com.seishin.astris-rpc</string>
            <key>CFBundleURLSchemes</key><array><string>astrisrpc</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP"
else
    # Hardened runtime + secure timestamp: required by notarization.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "OK: $APP  (copie dans /Applications : cp -R $APP /Applications/)"
