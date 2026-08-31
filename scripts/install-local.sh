#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
SOURCE_APP=${1:-"$PROJECT_ROOT/.build/xcode/Build/Products/Debug/MacNewFileKit.app"}
INSTALL_APP=${2:-"/Applications/MacNewFileKit.app"}
EXTENSION_ID="io.github.ywu73.MacNewFileKit.FinderSync"
LEGACY_EXTENSION_ID="com.example.RightClick.FinderSync"
SOURCE_EXTENSION="$SOURCE_APP/Contents/PlugIns/MacNewFileKitFinder.appex"

if [ ! -d "$SOURCE_APP" ]; then
    echo "Local install failed: app bundle not found at $SOURCE_APP" >&2
    echo "Run scripts/verify.sh first." >&2
    exit 2
fi

if [ -e "$INSTALL_APP" ]; then
    echo "Local install refused to overwrite existing app at $INSTALL_APP" >&2
    exit 2
fi

echo "Verifying source signature..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$SOURCE_APP"

echo "Installing MacNewFileKit..."
/usr/bin/ditto "$SOURCE_APP" "$INSTALL_APP"

echo "Verifying installed signature..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$INSTALL_APP"

INSTALLED_EXTENSION="$INSTALL_APP/Contents/PlugIns/MacNewFileKitFinder.appex"
if [ ! -d "$INSTALLED_EXTENSION" ]; then
    echo "Local install failed: embedded Finder extension is missing." >&2
    exit 2
fi

echo "Disabling the pre-rename Finder extension..."
/usr/bin/pluginkit -e ignore -i "$LEGACY_EXTENSION_ID" 2>/dev/null || true
/usr/bin/killall RightClickFinder 2>/dev/null || true

echo "Registering MacNewFileKit Finder extension..."
/usr/bin/pluginkit -r "$SOURCE_EXTENSION" 2>/dev/null || true
/usr/bin/pluginkit -a "$INSTALLED_EXTENSION"
/usr/bin/pluginkit -e use -i "$EXTENSION_ID"

echo "Reloading Finder..."
/usr/bin/killall Finder 2>/dev/null || true

echo "Local install ready: $INSTALL_APP"
echo "Finder extension identifier: $EXTENSION_ID"
