# Local iOS validation - 2026-09-05

This section records the earlier build, before the manual-capture and startup
recovery changes. It is not approval of the new TestFlight candidate. Track the
candidate's device checks in [qa-iphone.md](qa-iphone.md).

## Historical completed checks

- Regenerated with `.xcodegen/generate-local.sh`, preserving ignored local signing configuration. Local signing values are excluded from the commit.
- SwiftLint strict: zero violations across 1,563 files.
- Final FENR suite: 1,278 tests passed (1,395 executions including parameterized cases), zero failures or skipped tests.
- Focused planning tests cover no current location, an offline URL error, and an empty route response. They verify errors, cleared loading, and no active guidance/request as applicable.
- FENR and FENRDebug simulator builds, unsigned Release simulator build, and production Release device archive succeeded.
- The local archive is `build/app-store/FENR.xcarchive`; it is ignored build output and is not committed.
- `codesign --verify --deep --strict` passed for the archived app.
- `scripts/validate-app-store-resources.py --archive build/app-store/FENR.xcarchive` passed. Four manifests match their sources, both iOS extensions are present, usage descriptions and routing registration are present, and no Watch app is embedded.
- Release symbol inspection found no additional direct required-reason API use in BLETraceData or either extension executable.
- iPhone 17, iOS 26.5: inspected Settings and Acknowledgments. Support opens `https://fenr.to` from both the normal and demo experiences. Legal links open exactly `https://fenr.to/privacy` and `https://fenr.to/terms` in Safari.
- Explore demo > Start demo works without a motorcycle connection. To reach Settings, swipe up through the dashboard central cards, then tap Open Settings.
- Rotation preserves portrait Settings under the existing AppPresentationPolicy; the dashboard uses landscape. The orientation policy is unchanged.
- GeoJSON geometry, worldwide point coverage, and both iOS scheme references passed validation.
- Live MapKit probes on macOS returned three alternatives each for Madrid, New York, and Tokyo. An ocean request returned MKErrorDomain code 2. These are provider checks, not end-to-end iOS route UI tests.

## Remaining checks before submission

- Complete a final iPhone navigation smoke test with location denied, Internet unavailable, and a destination with no road route. Automated tests cover these planning failures; this run did not manually reproduce all three in the iOS UI.
- Validate/distribute the archive in Organizer with the intended App Store account. Local signature verification does not establish distribution eligibility or Apple's upload acceptance.
- Resolve the website findings below and review the final legal content against the candidate.
- Complete [the App Store Connect checklist](README.md), upload coverage, and provide [demo review notes](../app-review-demo.md).
- Review Apple's processing feedback before requesting App Review.

The owner reported physical traction-control and bike-lock testing on 2026-09-05.
No firmware inventory or new instrumented captures were supplied for this release
pass. The historical checks above do not independently reproduce that report or
establish broader hardware/firmware compatibility.

## Current preparation checks - 2026-09-05

These are source/metadata and public HTTP checks, not candidate-build acceptance:

- `asc metadata validate --dir store/metadata`: valid; two files, zero errors and
  zero warnings. No remote metadata, contact details or release state was changed.
- `python3 scripts/validate-app-store-resources.py`: source manifests, worldwide
  coverage and iOS scheme references passed. The new archive has not been checked
  by this report.
- The four source privacy manifests remain consistent with the declared
  UserDefaults reasons: CA92.1, plus 1C8F.1 for RideNavigationData's shared access.
  App Privacy questionnaire answers were not retrieved or validated.
- HTTP GET returned 200 at `https://fenr.to`, `/privacy` and `/terms`, retaining
  those final URLs. Legal pages contain substantive text and contact links. This
  establishes availability and content presence, not legal sufficiency or email
  delivery. The browser research provider could not open these URLs; checks used
  ordinary HTTP retrieval without authentication.

Concrete website findings requiring follow-up:

- The homepage still points its TestFlight links at
  `https://testflight.apple.com/join/FENRTEST`; replace with the intended invitation
  or remove the placeholder before distribution.
- The homepage has no direct contact link, while the legal pages do. Add a readily
  discoverable support route and verify the contact channel without publishing
  private App Store Connect contact details.
- The privacy page's Bluetooth-log section does not explain manual Start/Stop and
  says a connected session may continue creating records. Align it with the
  candidate's opt-in capture, disconnected Start, Stop and disabled-on-relaunch
  behavior; preserve the separate explanation of Apple's TestFlight diagnostics.
- Website/legal copy describes the Watch implementation. Clarify that the first
  beta distributes iPhone only, with Share and Live Activity extensions.

Remaining candidate tests, archive validation, device behavior and Apple-side
processing must be recorded after they actually run. None is inferred from these
source, metadata or website checks.


## Historical cleanup validation - 2026-09-05

- The complete iOS unit suite passed 1,320 tests with no failures or skips.
  After the mini-map placement change, all eight mini-mode tests passed,
  including bounds cases across scales, orientations and compact screens.
- Strict SwiftLint, source App Store resource validation and the four review
  document generator tests passed.
- FENRDebug built for signed simulator UI testing. Production FENR and FENRWatch
  Release simulator builds passed; the iPhone build was repeated after the final navigation-header fix.
- Both manual diagnostics UI tests passed on an iPhone 17 simulator: disconnected
  Start, background/return, reconnection, Stop, export, relaunch, deletion and
  recoverable history/writer errors. All 12 attached screenshots were reviewed.
- Generated test results and captures remain in ignored `build/testflight-qa/`.
  Local signing overrides are retained only in ignored configuration; the project
  contains repository signing placeholders.

These checks precede the owner's 2026-09-06 removal of the temporary UI-test
harness and injected scenarios. Future end-to-end checks are manual as described
in [testing.md](../testing.md); these results do not approve the post-removal build.

These checks validate the earlier cleanup, not the complete release matrix, physical
vehicle behavior or distribution signing. UI correction results are recorded in
[qa-iphone.md](qa-iphone.md).

## Current code validation - 2026-09-06

After removing the temporary UI-test targets and injected QA scenarios, the full
remaining iOS suite passed 1,312 tests with no failures or skips
(`build/testflight-qa/remove-qa-unit-tests.xcresult`). FENRDebug, FENR Release and
FENRWatch Release simulator builds, strict lint and source resource validation
passed. The normal debug emulator launched on the SE simulator without QA launch
arguments. This is a startup smoke check, not a new end-to-end acceptance run.
The public demo and manual diagnostic capture remain implemented; the broader
manual release matrix and distribution archive validation are still pending.
