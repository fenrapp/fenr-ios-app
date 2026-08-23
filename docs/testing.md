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
xcodegen generate
swiftlint lint --strict
FENR_SIMULATOR='<an installed iOS Simulator name>'
xcodebuild -project FENR.xcodeproj -scheme FENR \
  -destination "platform=iOS Simulator,name=$FENR_SIMULATOR" test
```

For UI work, also build `FENRDebug` and inspect the intended orientation/device in the simulator.
