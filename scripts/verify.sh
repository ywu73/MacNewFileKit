#!/bin/sh

set -eu

scripts/verify-core.sh

if ! command -v xcodebuild >/dev/null 2>&1 \
    || ! xcodebuild -version >/dev/null 2>&1; then
    echo "Full verification failed: full Xcode is not active." >&2
    exit 2
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Full verification failed: XcodeGen is not installed." >&2
    exit 2
fi

xcodegen generate
xcodebuild \
    -project RightClick.xcodeproj \
    -scheme RightClick \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath .build/xcode \
    CODE_SIGNING_ALLOWED=NO \
    build

scripts/sign-local.sh \
    .build/xcode/Build/Products/Debug/RightClick.app
