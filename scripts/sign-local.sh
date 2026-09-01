#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
APP_PATH=${1:-"$PROJECT_ROOT/.build/xcode/Build/Products/Debug/MacNewFileKit.app"}
SIGNING_PROFILE=${2:-"local-global"}
EXTENSION_PATH="$APP_PATH/Contents/PlugIns/MacNewFileKitFinder.appex"
APP_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKit.entitlements"
SHARED_LOCAL_REQUIREMENT='=designated => identifier "io.github.ywu73.MacNewFileKit" or identifier "io.github.ywu73.MacNewFileKit.FinderSync"'

case "$SIGNING_PROFILE" in
    local-global)
        EXTENSION_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKitFinder.local.entitlements"
        ;;
    authorized-folders)
        EXTENSION_ENTITLEMENTS="$PROJECT_ROOT/Config/MacNewFileKitFinder.entitlements"
        ;;
    *)
        echo "Local signing failed: unknown profile '$SIGNING_PROFILE'." >&2
        echo "Expected local-global or authorized-folders." >&2
        exit 2
        ;;
esac

sign_bundle() {
    bundle_path=$1
    entitlements_path=$2
    identifier=$3

    if [ "$SIGNING_PROFILE" = "authorized-folders" ]; then
        /usr/bin/codesign \
            --force \
            --sign - \
            --timestamp=none \
            --generate-entitlement-der \
            --entitlements "$entitlements_path" \
            --identifier "$identifier" \
            --requirements "$SHARED_LOCAL_REQUIREMENT" \
            "$bundle_path"
    else
        /usr/bin/codesign \
            --force \
            --sign - \
            --timestamp=none \
            --generate-entitlement-der \
            --entitlements "$entitlements_path" \
            --identifier "$identifier" \
            "$bundle_path"
    fi
}

if [ ! -d "$APP_PATH" ]; then
    echo "Local signing failed: app bundle not found at $APP_PATH" >&2
    exit 2
fi

if [ ! -d "$EXTENSION_PATH" ]; then
    echo "Local signing failed: Finder extension not found at $EXTENSION_PATH" >&2
    exit 2
fi

echo "Signing Finder extension ad hoc with profile: $SIGNING_PROFILE"
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

echo "Local ad hoc signature ready ($SIGNING_PROFILE): $APP_PATH"
