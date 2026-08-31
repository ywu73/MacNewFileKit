#!/bin/sh

set -eu

swift test

modules_path="$(swift build --show-bin-path)/Modules"

swiftc \
    -typecheck \
    -module-name MacNewFileKitApplication \
    -I "$modules_path" \
    -framework AppKit \
    -framework FinderSync \
    MacNewFileKitApp/MacNewFileKitApp.swift \
    MacNewFileKitApp/SettingsModel.swift \
    MacNewFileKitApp/ContentView.swift

swiftc \
    -typecheck \
    -module-name MacNewFileKitFinderExtension \
    -I "$modules_path" \
    -framework AppKit \
    -framework FinderSync \
    MacNewFileKitFinder/FinderSync.swift

plutil -lint \
    Config/MacNewFileKit.entitlements \
    Config/MacNewFileKitFinder.entitlements \
    Config/MacNewFileKitFinder.local.entitlements
