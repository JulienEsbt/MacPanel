#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodegen generate
xcodebuild -scheme MacPanel -destination 'platform=macOS' -derivedDataPath .build test
