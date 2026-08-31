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
- A development team with an App Group entitlement

The checked-in identifiers use `com.example.RightClick` and
`group.com.example.RightClick` placeholders. Replace both bundle identifiers
and the App Group value in `project.yml` and `Config/*.entitlements` before
signing a runnable build.

## Development

Run the platform-independent core tests with Command Line Tools:

```sh
scripts/verify-core.sh
```

After installing full Xcode and XcodeGen:

```sh
scripts/verify.sh
```

To run the Finder integration, configure real bundle/App Group identifiers,
select a development team, build the app, then use **Manage Finder Extensions**
inside RightClick. The extension currently monitors `/`; this deliberate MVP
choice must be validated on a signed build across local folders, Desktop, and
external volumes before it is treated as supported behavior.

## Verification boundary

Unit tests validate filename safety, content, collision handling, concurrent
creation, and shared preference persistence. A signed Finder integration test
still requires full Xcode and manual extension enablement on macOS.

`scripts/verify.sh` is deliberately fail-closed: it exits unsuccessfully when
full Xcode or XcodeGen is missing instead of reporting a skipped integration
build as a complete verification.
