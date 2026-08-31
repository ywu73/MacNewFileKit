#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
APP_PATH=${1:-"$PROJECT_ROOT/.build/xcode/Build/Products/Debug/MacNewFileKit.app"}
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/MacNewFileKitFinder.appex"
APP_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKit.entitlements"
EXTENSION_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKitFinder.local.entitlements"

if [ ! -d "$APP_PATH" ]; then
    echo "Local signing failed: app bundle not found at $APP_PATH" >&2
    exit 2
fi

if [ ! -d "$EXTENSION_PATH" ]; then
    echo "Local signing failed: Finder extension not found at $EXTENSION_PATH" >&2
    exit 2
fi

echo "Signing Finder extension ad hoc..."
/usr/bin/codesign \
    --force \
    --sign - \
    --timestamp=none \
    --generate-entitlement-der \
    --entitlements "$EXTENSION_ENTITLEMENTS" \
    --identifier io.github.ywu73.MacNewFileKit.FinderSync \
    "$EXTENSION_PATH"

echo "Signing containing app ad hoc..."
/usr/bin/codesign \
    --force \
    --sign - \
    --timestamp=none \
    --generate-entitlement-der \
    --entitlements "$APP_ENTITLEMENTS" \
    --identifier io.github.ywu73.MacNewFileKit \
    "$APP_PATH"

echo "Verifying nested extension signature..."
/usr/bin/codesign --verify --strict --verbose=2 "$EXTENSION_PATH"

echo "Verifying containing app and nested code..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Local ad hoc signature ready: $APP_PATH"
