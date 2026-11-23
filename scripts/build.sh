#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p .build Resources
xcrun swift -module-cache-path "$PWD/.build/ModuleCache" scripts/Icon.swift "$PWD/.build/MacPanel.iconset"
/usr/bin/iconutil -c icns .build/MacPanel.iconset -o Resources/AppIcon.icns
xcodegen generate
xcodebuild -scheme MacPanel -configuration Release -destination 'platform=macOS' \
  -derivedDataPath .build CODE_SIGN_IDENTITY="${MACPANEL_SIGN_IDENTITY:--}" \
  DEVELOPMENT_TEAM="${MACPANEL_TEAM:-}" build
codesign --verify --deep --strict .build/Build/Products/Release/MacPanel.app
