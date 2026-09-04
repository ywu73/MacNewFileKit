#!/bin/sh

set -eu

swift test

for template in \
    Sources/FileCreationCore/Resources/blank.docx \
    Sources/FileCreationCore/Resources/blank.xlsx \
    Sources/FileCreationCore/Resources/blank.pptx
do
    unzip -tq "$template" >/dev/null
done

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
    Config/MacNewFileKit.local.entitlements \
    Config/MacNewFileKitFinder.entitlements \
    Config/MacNewFileKitFinder.local.entitlements

if rg -q \
    'com\.apple\.security\.application-groups' \
    Config/MacNewFileKit.local.entitlements \
    Config/MacNewFileKitFinder.local.entitlements
then
    echo "Core verification failed: local entitlements include an App Group." >&2
    exit 2
fi

if [ "$(/usr/libexec/PlistBuddy \
    -c 'Print :com.apple.security.temporary-exception.files.absolute-path.read-write:0' \
    Config/MacNewFileKitFinder.local.entitlements)" != "/" ]
then
    echo "Core verification failed: local global Finder access lacks its matching entitlement." >&2
    exit 2
fi
