# Testing

## Test layout

- Test suites contain scenarios and assertions.
- `Tests/TestDoubles/` holds reusable fakes, mocks, spies, stubs and recorders.
- `Tests/Support/` holds factories assembling production objects.
- `Tests/Fixtures/` holds immutable input data.

Use `TestSupport.waitUntil` for bounded asynchronous polling and
`TestSupport.TestEventHub` for shared `AsyncStream` coordination. Prioritize
Bluetooth lifecycle, persistence, protocol decoding, measurement mapping and
rider-visible state transitions when changing behavior.

## Setup

Generate the project as described in [Development](development.md), then select
installed simulators:

```sh
xcrun simctl list devices available
FENR_IOS_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5'
FENR_WATCH_DESTINATION='platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5'
```

These example destinations match the CI configuration in
[ci.yml](../.github/workflows/ci.yml). Substitute installed device names and
runtimes locally. The deployment targets remain iOS 17 and watchOS 10; running
tests on a newer simulator does not establish runtime coverage of those minimums.

## Lint and iPhone tests

```sh
swiftlint lint --strict
xcodebuild -project FENR.xcodeproj -scheme FENR \
  -destination "$FENR_IOS_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
xcodebuild -project FENR.xcodeproj -scheme FENRDebug \
  -destination "$FENR_IOS_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Use `-only-testing:<target>/<suite>` for focused runs. For manual simulator checks
that use Keychain-backed PIN storage, build with ad hoc signing instead:
`CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_IDENTITY=-`.

## Watch tests

```sh
xcodebuild -project FENR.xcodeproj -scheme FENRWatchDebug \
  -destination "$FENR_WATCH_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO test
```

The debug Watch app starts in charging. After installing it, use the Watch UDID
from `simctl list` to select a scenario:

```sh
FENR_WATCH_SIMULATOR_ID='<watch-simulator-udid>'
xcrun simctl launch --terminate-running-process \
  "$FENR_WATCH_SIMULATOR_ID" com.fenr.watch.debug -debugScenario=riding
xcrun simctl launch --terminate-running-process \
  "$FENR_WATCH_SIMULATOR_ID" com.fenr.watch.debug -debugScenario=charging
```

## Release builds

```sh
xcodebuild -project FENR.xcodeproj -scheme FENR -configuration Release \
  -destination "$FENR_IOS_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
xcodebuild -project FENR.xcodeproj -scheme FENRWatch -configuration Release \
  -destination "$FENR_WATCH_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

For compatibility changes, compile with the deployment targets in `project.yml`
and exercise an older supported runtime as well as iOS 26's Liquid Glass path.
Do not raise the deployment target in validation commands to hide API errors.

## Manual checks

Use `FENRDebug` for emulated vehicle scenarios and production `FENR` for the
[public demo](app-review-demo.md) and onboarding. Inspect changed screens on the
intended device and orientation, including a compact iPhone when layout changes.
Check light/dark appearance, text sizing, accessible labels and error recovery
where relevant. Exercise Diagnostics Start/Stop and disabled capture on relaunch
when changing recording behavior.

Use synthetic data. Keep screenshots, videos, logs, performance traces and
`.xcresult` bundles outside Git. Simulator tests do not establish physical
Bluetooth reconnection, vehicle-write confirmation or real GPS movement.

## Store resources

```sh
python3 scripts/validate-app-store-resources.py
asc metadata validate --dir store/metadata
.asc/venv/bin/python3 -m unittest discover -s scripts/tests -p 'test_review_document.py'
```

Install the optional ASC/PDF tooling using [store/README.md](../store/README.md).
These checks validate repository resources and the reviewer-document generator;
they do not submit or upload anything.

See [Security](../SECURITY.md) for the credential scan and sensitive-data review.
