#!/bin/bash
set -euo pipefail

APP_NAME="mini-satset"
VERSION="1.0.0"
APP_BUNDLE="${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}-${VERSION}.dmg"
SWIFT_FILES=$(find Sources -name "*.swift")

echo "=== Compiling with swiftc ==="
mkdir -p bin dist "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"

# Ensure icon exists
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "Generating AppIcon.icns..."
    swift Resources/scripts/generate_icon.swift Resources/icon_1024.png
    chmod +x Resources/scripts/make-icns.sh
    ./Resources/scripts/make-icns.sh
fi

# Try Universal Binary (arm64 + x86_64)
if swiftc -O -whole-module-optimization -target arm64-apple-macos13.0 ${SWIFT_FILES} -o bin/${APP_NAME}-arm64 2>/dev/null && \
   swiftc -O -whole-module-optimization -target x86_64-apple-macos13.0 ${SWIFT_FILES} -o bin/${APP_NAME}-x86 2>/dev/null; then
    echo "Creating Universal 2 binary with lipo..."
    lipo -create -output "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" bin/${APP_NAME}-arm64 bin/${APP_NAME}-x86
else
    echo "Compiling native host architecture with -O..."
    swiftc -O -whole-module-optimization ${SWIFT_FILES} -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
fi

cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "=== Creating DMG Package ==="
rm -f "${DMG_PATH}"
TMP_DMG_DIR=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${TMP_DMG_DIR}/"
ln -s /Applications "${TMP_DMG_DIR}/Applications"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${TMP_DMG_DIR}" \
    -ov -format UDZO \
    "${DMG_PATH}"

rm -rf "${TMP_DMG_DIR}"
echo "=== DMG Created at: ${DMG_PATH} ==="
