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

The app is predominantly read-only, with a narrowly scoped authenticated VCU write path for the verified charging-power and charge-target configuration. Any vehicle-facing write must preserve unrelated configuration fields, be firmware-gated, pass a no-op guard, run serially with timeout recovery, and be confirmed by telemetry. Do not add arbitrary configuration writes or commands affecting riding maps, vehicle behaviour, safety controls, or firmware.
