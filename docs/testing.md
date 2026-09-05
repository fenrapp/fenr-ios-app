# Testing

## Layout

- Test suites contain scenarios and assertions.
- `Tests/TestDoubles/` holds fakes, mocks, spies, stubs, no-ops, recorders, and test event hubs.
- `Tests/Support/` holds factories that assemble production objects.
- `Tests/Fixtures/` holds immutable input data.

This keeps reusable collaborators visible and prevents test suites from becoming hidden dependency containers.

## Async tests

Use `TestSupport.waitUntil` for bounded asynchronous polling instead of ad hoc yield loops. Use `TestSupport.TestEventHub` when multiple tests or collaborators coordinate an `AsyncStream`.

## What to cover

Prioritize changes to:

- Bluetooth lifecycle and reconnection policy.
- Persistence and settings changes.
- Protocol decoder contracts and fixture data.
- Measurement/unit mapping.
- State transitions shown to riders.

## Commands

```sh
.xcodegen/generate-local.sh
swiftlint lint --strict
FENR_IOS_SIMULATOR='iPhone 17'
FENR_WATCH_SIMULATOR='Apple Watch Series 11 (46mm)'
xcodebuild -project FENR.xcodeproj -scheme FENR \
  -destination "platform=iOS Simulator,name=$FENR_IOS_SIMULATOR,OS=26.5" test
```

The reproducible local baseline uses Xcode 26.6, iPhone 17 with iOS 26.5, and Apple Watch Series 11 (46mm) with watchOS 26.5.

For UI work, also build `FENRDebug` without signing and inspect the intended orientation/device in the simulator.

```sh
xcodebuild -project FENR.xcodeproj -scheme FENRDebug \
  -destination "platform=iOS Simulator,name=$FENR_IOS_SIMULATOR,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

For Watch changes, build `FENRWatchDebug` with an installed watchOS runtime and inspect both the ride and charging states. The Watch dashboard test target is `WatchDashboardTests`.

```sh
xcodebuild -project FENR.xcodeproj -scheme FENRWatchDebug \
  -destination "platform=watchOS Simulator,name=$FENR_WATCH_SIMULATOR,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

The debug Watch app starts in the emulator's charging scenario. After building,
use the Watch simulator UDID reported by `xcrun simctl list devices available`
to launch the default or an explicit dashboard scenario. Unknown or malformed
scenario values also fall back to charging.

```sh
FENR_WATCH_SIMULATOR_ID='<watch-simulator-udid>'
xcrun simctl launch --terminate-running-process \
  "$FENR_WATCH_SIMULATOR_ID" com.fenr.watch.debug
xcrun simctl launch --terminate-running-process \
  "$FENR_WATCH_SIMULATOR_ID" com.fenr.watch.debug -debugScenario=riding
xcrun simctl launch --terminate-running-process \
  "$FENR_WATCH_SIMULATOR_ID" com.fenr.watch.debug -debugScenario=charging
```

Before handoff, validate both production release schemes without signing:

```sh
xcodebuild -project FENR.xcodeproj -scheme FENR -configuration Release \
  -destination "platform=iOS Simulator,name=$FENR_IOS_SIMULATOR,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project FENR.xcodeproj -scheme FENRWatch -configuration Release \
  -destination "platform=watchOS Simulator,name=$FENR_WATCH_SIMULATOR,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

## App Store materials

Use the setup instructions in [store/README.md](../store/README.md), then run:

```sh
asc metadata validate --dir store/metadata
.asc/venv/bin/python3 -m unittest discover -s scripts/tests -p 'test_review_document.py'
```

The PDF tests are local and exclude the engineering appendix from reviewer output.
Use `asc metadata push --dry-run` to compare the files with Apple without writes.
Screenshots are supplied by the owner.
