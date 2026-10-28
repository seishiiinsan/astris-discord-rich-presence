#!/bin/bash
# Package build/AstrisRPC.app into build/AstrisRPC.dmg (drag-to-Applications)
set -euo pipefail
cd "$(dirname "$0")"

STAGE=build/dmg
rm -rf "$STAGE" build/AstrisRPC.dmg
mkdir -p "$STAGE"
cp -R build/AstrisRPC.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Astris RPC" -srcfolder "$STAGE" -ov -format UDZO build/AstrisRPC.dmg
rm -rf "$STAGE"
if [[ "${SIGN_IDENTITY:--}" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" build/AstrisRPC.dmg
fi
echo "OK: build/AstrisRPC.dmg"
