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

CI runs iPhone unit tests and builds on pushes and pull requests. Watch validation
runs locally and in the scheduled/manual compatibility matrix in
[ci.yml](../.github/workflows/ci.yml). Substitute installed device names and
runtimes locally. The deployment targets remain iOS 17 and watchOS 10; running
tests on a newer simulator does not establish runtime coverage of those minimums.

CI creates its iPhone test simulator explicitly and selects it by UDID. Build-only
steps use `generic/platform=iOS Simulator`, so they do not require a pre-created
device on the runner.

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

## Partial Bluetooth telemetry

Keep the original security handshake mandatory. After authentication, one decoded
speed, battery SOC, or odometer dataset can open the dashboard. The other datasets
remain optional. Verify unavailable values, late samples, one bounded retry per
failed telemetry operation, and configuration readiness without all six telemetry
subscriptions. Without any dashboard dataset, retry readable metrics at 15 seconds
and report a startup failure at 30 seconds. Physical motorcycle validation is required.

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

## Architecture and app packaging

```sh
python3 scripts/validate-architecture.py --report /tmp/fenr-architecture.json
python3 -m unittest discover -s scripts/tests -p 'test_architecture.py'
python3 -m unittest discover -s scripts/tests -p 'test_compatibility_runtime.py'
python3 -m unittest discover -s scripts/tests -p 'test_runtime_frameworks.py'
```

The architecture validator reads `xcodegen dump --type parsed-json --no-env`, so
includes and target templates are resolved before checking missing targets,
cycles, layer boundaries, direct module imports, UI infrastructure imports, and
legacy observation wrappers throughout owned production Swift. Its three named
exceptions include their reasons and fail validation when they become unused.
This source check does not replace review of inferred domain types passed into UI.

After building an app with an explicit `-derivedDataPath`, validate its actual
framework dependencies. For example, after a Watch debug build:

```sh
python3 scripts/validate-runtime-frameworks.py \
  --app /tmp/fenr-watch/Build/Products/Debug-watchsimulator/FENRWatchDebug.app \
  --report /tmp/fenr-watch-embedding.json
```

Run this for both Debug and Release iPhone and Watch apps. Hostless unit tests can
pass while an executable is missing a transitive framework and fails in dyld at
launch. The validator inspects Mach-O dependencies, including debug dylibs and
nested executables. Launch and visual QA remain required for changed screens.

## Scheduled runtime compatibility

CI keeps its pull-request and main-branch checks. Its additional compatibility
matrix runs each Monday at 05:23 UTC and on manual `workflow_dispatch`, requesting
iOS 17.5 and watchOS 10.5 with the existing deployment targets unchanged.
The preflight first looks for an installed official runtime and, if absent, tries
`xcodebuild -downloadPlatform <platform> -buildVersion <version>`. It creates and
boots a compatible temporary simulator before running tests and building the app.

If the requested runtime cannot be installed or booted, preflight selects the
oldest available runtime at or above the app's deployment target. Its JSON report,
Actions warning, and job summary name both the requested and selected versions.
If none can boot, the report explicitly records that compatibility was not tested.
A fallback never counts as coverage of the requested runtime. Provisioning tool
errors and test/build failures fail the job; a documented unavailable-runtime gap
does not. Reports, build logs, and result bundles are uploaded for seven days.

To run preflight locally (it may download an official runtime and creates a device):

```sh
python3 scripts/prepare-compatibility-runtime.py --platform iOS --version 17.5 \
  --report /tmp/fenr-ios-runtime.json
python3 scripts/prepare-compatibility-runtime.py --platform watchOS --version 10.5 \
  --report /tmp/fenr-watch-runtime.json
```

Use the report's `destination` for `xcodebuild` and delete its temporary `deviceID`
after testing. CI performs that cleanup automatically.

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
