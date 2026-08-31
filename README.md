# RightClick

RightClick is a native macOS Finder extension that adds a Windows-style
**New File** menu. The first release focuses on creating text, Markdown, JSON,
and user-defined text templates without overwriting existing files.

## Current scope

- Finder background, selected folder, and Desktop context menus
- Collision-safe names such as `untitled.txt` and `untitled 2.txt`
- Text, Markdown, JSON, and custom text templates
- Shared settings through an App Group
- Finder selection after creation

RightClick does not use Accessibility permission or keyboard simulation. The
public Finder API can select a newly created file, but it does not expose an API
for entering inline rename mode.

## Architecture

```text
RightClick.app
├── RightClickApp          settings and extension onboarding
├── RightClickFinder       Finder Sync extension
├── FileCreationCore       exclusive creation and filename allocation
└── RightClickShared       App Group preference model
```

`FileCreationCore` uses `open(2)` with `O_CREAT | O_EXCL`. Name selection and
creation therefore form one exclusive operation instead of a vulnerable
"check, then write" sequence.

## Requirements

- macOS 13 or later
- Full Xcode installation
- XcodeGen to generate `RightClick.xcodeproj` from `project.yml`
- No Apple Developer account is required for local ad hoc builds

The checked-in identifiers use `com.example.RightClick` and
`group.com.example.RightClick` placeholders. Replace both bundle identifiers
and the App Group value before creating a distributable build.

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
written to `.build/xcode/Build/Products/Debug/RightClick.app`.

The ad hoc Finder extension uses
`Config/RightClickFinder.local.entitlements`, which adds a temporary `/`
read/write sandbox exception so the global Finder workflow can be exercised on
the developer's Mac. The normal `Config/RightClickFinder.entitlements` does not
contain that exception.

To run the Finder integration, launch that app and use **Manage Finder
Extensions** inside RightClick. The extension currently monitors `/`; this
deliberate MVP choice must be validated across local folders, Desktop, and
external volumes before it is treated as supported behavior.

Ad hoc signing and the temporary filesystem exception are for local testing
only. Distribution to other Macs still requires an appropriate Apple signing
identity, notarization, and a release-safe filesystem-access design.

## Verification boundary

Unit tests validate filename safety, content, collision handling, concurrent
creation, and shared preference persistence. The build script validates the
local ad hoc signature; Finder integration still requires extension enablement
and live Finder interaction on macOS.

`scripts/verify.sh` is deliberately fail-closed: it exits unsuccessfully when
full Xcode or XcodeGen is missing instead of reporting a skipped integration
build as a complete verification.
