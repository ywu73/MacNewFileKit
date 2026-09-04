# Finder Sync technical spike

## Objective

Prove that a signed MacNewFileKit Finder Sync extension can expose a **New File**
menu and create a collision-safe file in the directory represented by the
Finder context menu.

## Confirmed API surface

Apple's Finder Sync API provides separate menu kinds for selected items,
container backgrounds, sidebar items, and the toolbar. During menu construction
and actions, `targetedURL()` and `selectedItemURLs()` expose the relevant Finder
URLs.

- [Finder Sync programming guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)
- [`directoryURLs`](https://developer.apple.com/documentation/findersync/fifindersynccontroller/directoryurls)
- [`selectedItemURLs()`](https://developer.apple.com/documentation/findersync/fifindersynccontroller/selecteditemurls())

The containing app can inspect extension status and open Apple's extension
management interface through `FIFinderSyncController`.

## Product risk

Apple documents Finder Sync primarily for file synchronization products and
explicitly says it is not intended as a general-purpose Finder customization
mechanism. MacNewFileKit's use is technically aligned with the contextual-menu API
but outside Apple's recommended product archetype. This is a release and App
Review risk, not evidence that the API cannot work.

## Verified local behavior

An ad hoc signed Debug build is recognized and enabled by `pluginkit`, and the
Finder background menu appears with Text Document, Markdown, and JSON actions.
Finder does not preserve `NSMenuItem.representedObject` when it bridges extension
menu items into its own context menu, so actions use standard menu tags with a
title fallback instead.

The standard sandbox entitlement allows the menu action to run but blocks writes
to arbitrary Finder locations. Live testing proved that app-scoped bookmarks
created by the ad hoc containing app cannot be restored by its separately hosted
Finder extension, even when both use a shared designated requirement. The local
signing flow therefore uses the saved authorized paths plus a development-only
absolute-path exception. It does not access an App Group container, and the
extension still registers menus only under saved authorized paths.

The installed local build was verified in Finder by creating `untitled.txt`.
Chrome then opened five consecutive webpage Save panels, and TextEdit opened
three native Save panels. The panels launched fresh Finder extension instances,
and none displayed the macOS prompt to access another app's data. Because the
prompt was caused by the extension's process-wide App Group access, removing
that access fixes the shared Save-panel path rather than a browser-specific path.

## Authorized-folder prototype

The containing app creates app-scoped security bookmarks for directories the
user selects with `NSOpenPanel`. A properly signed distribution stores them in
the App Group; the local ad hoc build stores them in a shared preferences domain.
The Finder extension resolves those bookmarks in a properly signed build and
keeps their security scopes active. For an ad hoc local build, it uses the saved
display path because cross-identity bookmark restoration fails. Both modes
register only those roots with `directoryURLs`. Path matching uses normalized path
components rather than string prefixes. A distributed notification refreshes the
registered roots after the user changes authorization.

Successful build and signature verification alone do not prove that bookmark
access survives Finder extension restart. That behavior remains a live-test exit
criterion for a properly Team-signed distribution build.

## Remaining assumptions

The following must not be treated as completed until tested with a signed app:

1. A properly Team-signed distribution lets the containing app and Finder
   extension share security-scoped directory bookmarks through the App Group.
2. Finder applies monitored-directory updates delivered by the containing app
   without requiring an extension restart.
3. Finder places the menu at an acceptable depth on every supported macOS
   version.
4. `activateFileViewerSelecting` reliably selects the new file without opening
   a duplicate Finder window.

## Manual test matrix

| Context | Expected destination | Required result |
|---|---|---|
| Folder background | Open folder | Create and select the new file |
| One selected folder | Selected folder | Create inside the folder |
| One selected file | File's parent | Create beside the selected file |
| Multiple selected items | Shared parent | Create beside the selected items |
| Desktop background | Desktop | Create and select the new file |
| Existing `untitled.txt` | Same directory | Create `untitled 2.txt` |
| Read-only directory | No destination | Show an actionable error |
| External writable volume | Current folder | Create without overwriting |

## Exit criteria

The spike is successful only when a real signed Debug build passes the local
folder, Desktop, collision, and permission-error cases. External-volume support
may remain explicitly unsupported if sandbox or Finder behavior is inconsistent.
Failure to build, sign, enable, or display the extension is a failed spike rather
than a partial success.
