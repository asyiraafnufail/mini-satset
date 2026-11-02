#!/bin/bash
set -euo pipefail

BASE_PNG="Resources/icon_1024.png"
ICONSET="Resources/AppIcon.iconset"
ICNS="Resources/AppIcon.icns"

mkdir -p "${ICONSET}"

sips -z 16 16     "${BASE_PNG}" --out "${ICONSET}/icon_16x16.png" >/dev/null
sips -z 32 32     "${BASE_PNG}" --out "${ICONSET}/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${BASE_PNG}" --out "${ICONSET}/icon_32x32.png" >/dev/null
sips -z 64 64     "${BASE_PNG}" --out "${ICONSET}/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${BASE_PNG}" --out "${ICONSET}/icon_128x128.png" >/dev/null
sips -z 256 256   "${BASE_PNG}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${BASE_PNG}" --out "${ICONSET}/icon_256x256.png" >/dev/null
sips -z 512 512   "${BASE_PNG}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${BASE_PNG}" --out "${ICONSET}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${BASE_PNG}" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null

iconutil -c icns "${ICONSET}" -o "${ICNS}"
rm -rf "${ICONSET}"
echo "AppIcon.icns created at: ${ICNS}"
