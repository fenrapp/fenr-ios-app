# Development

## Prerequisites

- A recent Xcode version with iOS 17+ and watchOS 10+ runtimes.
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

The app is predominantly read-only. Its authenticated VCU write paths cover verified charging-power and charge-target configuration plus guarded base-map horsepower, regenerative braking, TC, TC Regen, and bike lock. Any vehicle-facing write must preserve every unrelated value, be firmware- and capability-gated, pass a safe no-op guard, run serially with timeout recovery, and be confirmed by telemetry or a fresh read. Base-map responses may expose curve selector `0` or `mapIndex + 1`; reject all other selectors and normalize outgoing base-map writes to `mapIndex + 1`. Type `8` TC writes require VCU PIC firmware 1.10.1 or newer, whole percentages from 0 through 100 encoded as signed 16-bit tenths, write mode `0x0F`, a successful write status, and preservation of the sibling value. Base writes have physical write/read-back evidence. The owner reported physical TC and bike-lock testing on 2026-09-05; firmware inventory and new instrumented captures were not supplied for this release pass. Never accept an acknowledgement alone or hide a mismatched read-back. Do not add arbitrary configuration, custom curves, ownership, safety-control, or firmware writes.

## First TestFlight release

Ship iPhone with Share and Live Activity extensions; retain Watch code for later distribution. Diagnostic capture is manual and off at process launch. Verify disconnected Start, reconnect continuity, Stop and relaunch without recording. Technical logging must not be needed for telemetry, persistence or vehicle confirmations.

Run future end-to-end checks manually with the native Debug emulator and public production demo; the temporary automated UI-test harness and injected scenarios were removed. Use [the iPhone QA matrix](app-store/qa-iphone.md) for the required iPhone 17 reference, iPhone 17 Pro and iPhone SE 3 checks at default text size. Keep screenshots and result bundles in ignored build output. Existing validation reports do not pass the new candidate automatically.
