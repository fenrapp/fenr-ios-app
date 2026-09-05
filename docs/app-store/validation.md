# Local iOS validation - 2026-09-05

## Completed

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
- Review the website support contact, final links, and legal content. Opening correct URLs does not validate their contents.
- Complete [the App Store Connect checklist](README.md), upload coverage, and provide [demo review notes](../app-review-demo.md).
- Review Apple's processing feedback before requesting App Review.

Vehicle controls and Watch behavior are unchanged. These checks do not establish physical traction-control or bike-lock validation.
