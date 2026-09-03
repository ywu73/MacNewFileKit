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
- Shared settings through an App Group
- User-authorized folders backed by security-scoped bookmarks
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
└── MacNewFileKitShared    App Group preference model
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
identity (`codesign --sign -`). It preserves the sandbox and App Group
entitlements and finishes with strict signature verification. The signed app is
written to `.build/xcode/Build/Products/Debug/MacNewFileKit.app`.

The ad hoc Finder extension uses
`Config/MacNewFileKitFinder.local.entitlements`, which adds a temporary `/`
read/write sandbox exception so the global Finder workflow can be exercised on
the developer's Mac. The normal `Config/MacNewFileKitFinder.entitlements` does not
contain that exception.

To exercise the authorized-folder design without the temporary `/` exception,
build and sign with the restricted local profile:

```sh
MACNEWFILEKIT_SIGNING_PROFILE=authorized-folders scripts/verify.sh
```

This remains an ad hoc developer build. It proves which entitlements are embedded
and supports local runtime testing, but it is not a substitute for Developer ID
signing, notarization, or App Review.

To run the Finder integration, launch that app and use **Manage Finder
Extensions** inside MacNewFileKit. The extension monitors `/` so Finder can ask it
for menus globally, but it only returns the New File menu for folders covered by
a bookmark the user added in the containing app. Monitoring and write permission
are separate: the bookmark session controls whether creation is offered.

Ad hoc signing and the temporary filesystem exception are for local testing
only. Distribution to other Macs still requires an appropriate Apple signing
identity, notarization, and a release-safe filesystem-access design.

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

This installation path is for local development only. It uses the ad hoc build
and temporary filesystem exception described above, and is not a distributable
release.

## Verification boundary

Unit tests validate filename safety, content, collision handling, concurrent
creation, custom-template editing rules, authorized-directory matching, and
shared preference persistence. The build script validates the local ad hoc
signature; Finder integration still requires extension enablement and live
Finder interaction on macOS.

`scripts/verify.sh` is deliberately fail-closed: it exits unsuccessfully when
full Xcode or XcodeGen is missing instead of reporting a skipped integration
build as a complete verification.
