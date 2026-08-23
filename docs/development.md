# Development

## Prerequisites

- A recent Xcode version with an iOS 16+ runtime.
- XcodeGen: `brew install xcodegen`
- SwiftLint: `brew install swiftlint`

## Generate the project

`project.yml` is the source of truth for `FENR.xcodeproj`.

```sh
xcodegen generate
```

Open `FENR.xcodeproj` after generation. Do not commit local Xcode user data.

## Schemes

- `FENR`: the main app.
- `FENRDebug`: emulator-backed development app. It is useful for dashboard states and connection flows without hardware.

## Local checks

```sh
swiftlint lint --strict
FENR_SIMULATOR='<an installed iOS Simulator name>'
xcodebuild -project FENR.xcodeproj -scheme FENR \
  -destination "platform=iOS Simulator,name=$FENR_SIMULATOR" test
xcodebuild -project FENR.xcodeproj -scheme FENRDebug \
  -destination "platform=iOS Simulator,name=$FENR_SIMULATOR" build
xcodebuild -project FENR.xcodeproj -scheme FENR \
  -destination 'generic/platform=iOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

List available simulators with `xcrun simctl list devices available` and assign one to `FENR_SIMULATOR`.

## Safety boundary

The app is read-only. Keep vehicle-facing changes limited to the established authenticated telemetry connection. Do not implement undocumented write commands or product-control behaviour.
