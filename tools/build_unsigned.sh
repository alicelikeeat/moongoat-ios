#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]] || ! command -v xcodebuild >/dev/null; then
    echo "Requires macOS with Xcode 26+ and the iOS SDK. No IPA was produced." >&2
    exit 1
fi
xcodebuild -version
swift test
python3 tools/generate_project.py
xcodebuild -project MoonGoat.xcodeproj -scheme MoonGoat -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
APP=build/DerivedData/Build/Products/Release-iphoneos/MoonGoat.app
[[ -d "$APP" ]]
if codesign -d "$APP" >/dev/null 2>&1; then
    echo 'Expected unsigned app; found a signature. Aborting packaging.' >&2
    exit 1
fi
python3 tools/package_ipa.py "$APP" build/MoonGoat-unsigned.ipa
shasum -a 256 build/MoonGoat-unsigned.ipa > build/MoonGoat-unsigned.ipa.sha256
