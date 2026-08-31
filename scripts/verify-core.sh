#!/bin/sh

set -eu

swift test

modules_path="$(swift build --show-bin-path)/Modules"

swiftc \
    -typecheck \
    -module-name RightClickApplication \
    -I "$modules_path" \
    -framework AppKit \
    -framework FinderSync \
    RightClickApp/RightClickApp.swift \
    RightClickApp/SettingsModel.swift \
    RightClickApp/ContentView.swift

swiftc \
    -typecheck \
    -module-name RightClickFinderExtension \
    -I "$modules_path" \
    -framework AppKit \
    -framework FinderSync \
    RightClickFinder/FinderSync.swift

plutil -lint \
    Config/RightClick.entitlements \
    Config/RightClickFinder.entitlements
