# Development

## Prerequisites

- A recent Xcode version with iOS 16+ and watchOS 10+ runtimes.
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
- `FENRWatch`: standalone watchOS app that connects directly from the Watch.
- `FENRWatchDebug`: emulator-backed Watch app. It starts with a configured emulator profile and demonstrates the compact charging surface.

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
xcodebuild -project FENR.xcodeproj -scheme FENRWatch \
  -destination "platform=watchOS Simulator,name=$FENR_WATCH_SIMULATOR" build CODE_SIGNING_ALLOWED=NO
xcodebuild -project FENR.xcodeproj -scheme FENRWatchDebug \
  -destination "platform=watchOS Simulator,name=$FENR_WATCH_SIMULATOR" build CODE_SIGNING_ALLOWED=NO
```

List available simulators with `xcrun simctl list devices available` and assign an iPhone to `FENR_SIMULATOR` and an Apple Watch to `FENR_WATCH_SIMULATOR`.

## Safety boundary

The app is read-only. Keep vehicle-facing changes limited to the established authenticated telemetry connection. Do not implement undocumented write commands or product-control behaviour.
