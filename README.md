# MacNewFileKit

MacNewFileKit is a native macOS Finder extension that adds a Windows-style
**New File** menu. It creates text, Markdown, JSON, Word, Excel, PowerPoint,
and user-defined text templates without overwriting existing files.

## Current scope

- Finder background, selected folder, and Desktop context menus
- Collision-safe names such as `untitled.txt` and `untitled 2.txt`
- Text, Markdown, JSON, Word (`.docx`), Excel (`.xlsx`), PowerPoint (`.pptx`),
  and custom text templates
- Editable custom-template names, extensions, initial content, and ordering
- Shared settings through an App Group for distribution or a local shared
  preferences domain for ad hoc development
- Global Finder coverage on the startup disk and mounted volumes for local ad
  hoc builds
- User-authorized folders backed by security-scoped bookmarks for signed
  distribution builds
- Finder selection after creation

MacNewFileKit does not use Accessibility permission or keyboard simulation. The
public Finder API can select a newly created file, but it does not expose an API
for entering inline rename mode.

## Architecture

```text
MacNewFileKit.app
├── MacNewFileKitApp       settings and extension onboarding
├── MacNewFileKitFinder    Finder Sync extension
├── FileCreationCore       exclusive creation and filename allocation
└── MacNewFileKitShared    shared settings and Finder access policy
```

`FileCreationCore` uses `open(2)` with `O_CREAT | O_EXCL`. Name selection and
creation therefore form one exclusive operation instead of a vulnerable
"check, then write" sequence.

## Requirements

- macOS 13 or later
- Full Xcode installation
- XcodeGen to generate `MacNewFileKit.xcodeproj` from `project.yml`
- No Apple Developer account is required for local ad hoc builds

The checked-in identifiers use `io.github.ywu73.MacNewFileKit` and
`group.io.github.ywu73.MacNewFileKit`. Register the identifiers with an Apple
Developer team before creating a distributable build.

## Development

Run the platform-independent core tests with Command Line Tools:

```sh
scripts/verify-core.sh
```

After installing full Xcode and XcodeGen:

```sh
scripts/verify.sh
```

The verification script builds with Xcode-managed signing disabled, then signs
the embedded Finder extension before the containing app with a local ad hoc
identity (`codesign --sign -`). The local build uses a shared preferences domain
instead of an App Group container, because an ad hoc signature has no Team ID
with which macOS can authorize the App Group. An ad hoc app and its extension
also cannot restore each other's app-scoped security bookmarks. The local Finder
extension therefore receives a development-only absolute-path exception and
monitors the startup disk plus mounted volumes. It refreshes the mounted-volume
set every three seconds. The signed app is written to
`.build/xcode/Build/Products/Debug/MacNewFileKit.app`.

This remains an ad hoc developer build. It proves which entitlements are embedded
and supports local runtime testing, but it is not a substitute for Developer ID
signing, notarization, or App Review.

To run the Finder integration, launch that app and use **Manage Finder
Extensions** inside MacNewFileKit. Local ad hoc builds expose the Finder menu in
ordinary writable folders without requiring per-folder authorization.
Distribution builds keep the narrower authorized-folder mode: they resolve each
security-scoped bookmark and refresh their monitored roots after a cross-process
notification from the containing app.

The shared-preference temporary exception is for local testing only.
Distribution to other Macs still requires an appropriate Apple signing identity,
an authorized App Group, notarization, and App Review.

## Local installation

After `scripts/verify.sh` succeeds, install the ad hoc build in a stable location:

```sh
scripts/install-local.sh
```

The installer verifies the source and installed signatures, places the app at
`/Applications/MacNewFileKit.app`, disables the pre-rename RightClick extension,
registers the embedded MacNewFileKit Finder extension, and reloads Finder. It
refuses to overwrite an existing installation.

Open the app once to inspect the extension status or use **Manage Finder
Extensions** if macOS still requires approval. After the extension is enabled,
the settings app may be quit; Finder loads the extension independently.

This installation path is for local development only. It uses the ad hoc global
access mode described above and is not a distributable release.

## Verification boundary

Unit tests validate filename safety, content, collision handling, concurrent
creation, custom-template editing rules, authorized-directory matching, and
shared preference persistence. Tests also verify that global access is opt-in and
that its monitoring roots contain `/` plus mounted volumes. The build script
validates the local ad hoc signature; Finder integration still requires extension
enablement and live Finder interaction on macOS.

`scripts/verify.sh` is deliberately fail-closed: it exits unsuccessfully when
full Xcode or XcodeGen is missing instead of reporting a skipped integration
build as a complete verification.
