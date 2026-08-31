# Finder Sync technical spike

## Objective

Prove that a signed RightClick Finder Sync extension can expose a **New File**
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
mechanism. RightClick's use is technically aligned with the contextual-menu API
but outside Apple's recommended product archetype. This is a release and App
Review risk, not evidence that the API cannot work.

## Verified local behavior

An ad hoc signed Debug build is recognized and enabled by `pluginkit`, and the
Finder background menu appears with Text Document, Markdown, and JSON actions.
Finder does not preserve `NSMenuItem.representedObject` when it bridges extension
menu items into its own context menu, so actions use standard menu tags with a
title fallback instead.

The standard sandbox entitlement allows the menu action to run but blocks writes
to arbitrary Finder locations. The local ad hoc signing flow therefore uses a
separate entitlement file with a temporary `/` read/write exception. This proves
the Finder workflow locally without silently broadening the release entitlement.

## Remaining assumptions

The following must not be treated as completed until tested with a signed app:

1. Monitoring `/` exposes the menu consistently across ordinary local folders,
   Desktop, and mounted external volumes.
2. A release-safe filesystem-access design can cover the intended Finder scope
   without the local temporary exception.
3. Finder places the menu at an acceptable depth on every supported macOS
   version.
4. `activateFileViewerSelecting` reliably selects the new file without opening
   a duplicate Finder window.
5. Finder refreshes App Group preferences without restarting the extension.

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
