#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
APP_PATH=${1:-"$PROJECT_ROOT/.build/xcode/Build/Products/Debug/MacNewFileKit.app"}
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/MacNewFileKitFinder.appex"
EXTENSION_INFO_PLIST="$EXTENSION_PATH/Contents/Info.plist"
APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKit.local.entitlements"
EXTENSION_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKitFinder.local.entitlements"
SHARED_PREFERENCES_DOMAIN="io.github.ywu73.MacNewFileKit.shared"
GLOBAL_ACCESS_KEY="MacNewFileKitLocalGlobalAccess"
SHARED_LOCAL_REQUIREMENT='=designated => identifier "io.github.ywu73.MacNewFileKit" or identifier "io.github.ywu73.MacNewFileKit.FinderSync"'

sign_bundle() {
    bundle_path=$1
    entitlements_path=$2
    identifier=$3

    /usr/bin/codesign \
        --force \
        --sign - \
        --timestamp=none \
        --generate-entitlement-der \
        --entitlements "$entitlements_path" \
        --identifier "$identifier" \
        --requirements "$SHARED_LOCAL_REQUIREMENT" \
        "$bundle_path"
}

if [ ! -d "$APP_PATH" ]; then
    echo "Local signing failed: app bundle not found at $APP_PATH" >&2
    exit 2
fi

if [ ! -d "$EXTENSION_PATH" ]; then
    echo "Local signing failed: Finder extension not found at $EXTENSION_PATH" >&2
    exit 2
fi

/usr/libexec/PlistBuddy \
    -c "Add :MacNewFileKitSharedPreferencesDomain string $SHARED_PREFERENCES_DOMAIN" \
    "$APP_INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy \
        -c "Set :MacNewFileKitSharedPreferencesDomain $SHARED_PREFERENCES_DOMAIN" \
        "$APP_INFO_PLIST"

/usr/libexec/PlistBuddy \
    -c "Add :MacNewFileKitSharedPreferencesDomain string $SHARED_PREFERENCES_DOMAIN" \
    "$EXTENSION_INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy \
        -c "Set :MacNewFileKitSharedPreferencesDomain $SHARED_PREFERENCES_DOMAIN" \
        "$EXTENSION_INFO_PLIST"

/usr/libexec/PlistBuddy \
    -c "Add :$GLOBAL_ACCESS_KEY bool true" \
    "$APP_INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy \
        -c "Set :$GLOBAL_ACCESS_KEY true" \
        "$APP_INFO_PLIST"

/usr/libexec/PlistBuddy \
    -c "Add :$GLOBAL_ACCESS_KEY bool true" \
    "$EXTENSION_INFO_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy \
        -c "Set :$GLOBAL_ACCESS_KEY true" \
        "$EXTENSION_INFO_PLIST"

/usr/libexec/PlistBuddy \
    -c "Delete :MacNewFileKitLocalPathFallback" \
    "$EXTENSION_INFO_PLIST" 2>/dev/null \
    || true

echo "Signing Finder extension with local global-access entitlements..."
sign_bundle \
    "$EXTENSION_PATH" \
    "$EXTENSION_ENTITLEMENTS" \
    io.github.ywu73.MacNewFileKit.FinderSync

echo "Signing containing app ad hoc..."
sign_bundle \
    "$APP_PATH" \
    "$APP_ENTITLEMENTS" \
    io.github.ywu73.MacNewFileKit

echo "Verifying nested extension signature..."
/usr/bin/codesign --verify --strict --verbose=2 "$EXTENSION_PATH"

echo "Verifying containing app and nested code..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

for info_plist in "$APP_INFO_PLIST" "$EXTENSION_INFO_PLIST"
do
    if [ "$(/usr/libexec/PlistBuddy \
        -c "Print :$GLOBAL_ACCESS_KEY" \
        "$info_plist")" != "true" ]; then
        echo "Local signing failed: global Finder access is not enabled." >&2
        exit 2
    fi
done

echo "Local ad hoc signature ready: $APP_PATH"
