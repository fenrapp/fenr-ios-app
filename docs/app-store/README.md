# iOS App Store submission

This checklist covers the iPhone app and its Share and Live Activity extensions.
The first TestFlight release is iPhone-only. Watch implementation is retained for
a later release; deploying or authoring the website legal documents is outside
this preparation. Local validation does not establish App Review approval.

See [the dated local validation report](validation.md) for completed checks and
the remaining manual and App Store Connect verification.

## ASC workflow

Use [store/README.md](../../store/README.md) for direct ASC commands, TestFlight,
public metadata and owner-supplied final screenshots. Review notes and the PDF
attachment are generated from [the canonical demo guide](../app-review-demo.md).
The review path requires no physical motorcycle. Preparation, submission and
manual public release are separate commands; this checklist remains applicable.

## Privacy manifests

The following bundles declare `NSPrivacyAccessedAPICategoryUserDefaults`:

| Bundle | Reasons | Use |
| --- | --- | --- |
| FENR / FENRDebug | CA92.1 | App preferences and isolated demo defaults |
| BikeData | CA92.1 | Local bike profiles |
| SettingsData | CA92.1 | Local and VIN-scoped preferences |
| RideNavigationData | CA92.1, 1C8F.1 | Private demo/fallback defaults and shared incoming links |

The shared BikeData and SettingsData targets include their manifests only for iOS.
ShareExtension calls RideNavigationData's storage implementation; it does not
directly access UserDefaults. LiveActivityExtension does not directly use the
required-reason APIs found in this audit. Neither extension needs a duplicate
declaration for APIs implemented in a separately bundled dynamic framework.

BLETraceData uses `attributesOfItem(atPath:)` only to obtain `.size`. It does not
access file timestamps or the listed stat APIs directly. Do not declare file
timestamp access solely because this method can also return timestamps. Recheck
the Release binary and Apple's processing feedback when changing this code.

These manifests describe API access reasons. They do not replace App Store
Connect's App Privacy questionnaire or the privacy policy. Review the final data
flows, including map searches, directions, shared-link resolution, and optional
exports, before completing the questionnaire; local storage alone is not proof
of collection by the developer.

Apple references: [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
[API categories and reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).

## Encryption declaration

The FENR and FENRDebug iPhone targets declare `ITSAppUsesNonExemptEncryption: false`
in `project.yml`. XcodeGen writes the boolean into their generated Info.plist files.
The current authentication uses SHA-256 through Apple's CryptoKit; no independent
cipher implementation is bundled. Reassess this declaration if cryptographic
functionality or dependencies change. The declaration applies to newly built apps;
it does not modify an existing archive or uploaded build.

Apple reference: [non-exempt encryption declaration](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

## Routing coverage

Upload `routing-coverage.geojson` as **Routing App Coverage File** for the iOS
version in App Store Connect. The file is a single MultiPolygon with a closed
world boundary. Intermediate longitude vertices avoid an edge jumping across
the antimeridian. There are no holes or comments.

The coverage is worldwide. Road directions require Internet and are subject to
Apple Maps route availability; this is not a promise of a route for every point,
an off-road routing service, or worldwide offline maps.

XcodeGen's post-generation hook configures **Run > Options > Routing App Coverage
File** on the FENR and FENRDebug schemes. It does not change the Watch schemes or
simulate the user's GPS position. The GeoJSON is an App Store/Xcode resource,
not an app-bundle resource.

Apple references: [uploading coverage](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/upload-a-geographic-coverage-file/),
[GeoJSON format and simulator verification](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/ProvidingDirections/ProvidingDirections.html).

## Review notes and support

Use [the iPhone demo instructions](../app-review-demo.md) for Notes for Review.
The demo is available in the production build through **Explore demo** and needs
no account, real motorcycle, or Bluetooth permission. Explain hardware-dependent
features and simulated confirmations accurately.

Set **Support URL** to `https://fenr.to`. Settings > Help & Support opens this same
address from both the real and demo experiences.

Settings > Legal contains **Privacy Policy** (`https://fenr.to/privacy`) and
**Terms of Use** (`https://fenr.to/terms`). Both open in the system browser.
Both pages were reachable and contained legal text in the 2026-09-05 HTTP check.
Review their content against the final release behavior. Use the privacy URL in
App Store Connect as well: guideline 5.1.1(i) requires access both in the
app and in its metadata. The terms link is provided for convenience; Apple
applies its standard EULA unless a custom license is supplied in App Store Connect.

Settings > **Acknowledgments** credits Svag Mini, Svag Telemetry Format,
Stark Varg Garmin Bridge, and Bosch Garmin Bridge for the community reference
work already acknowledged by FENR's research project. XcodeGen, SwiftLint and App Store Connect CLI are
listed separately as development tools. These credits do not claim that the
community projects' code is bundled with the app or replace license notices for
any future vendored dependencies.

Before submission, the website owner must replace or remove the observed
`https://testflight.apple.com/join/FENRTEST` placeholder. The homepage has no direct
contact link; the published legal pages do expose contact links. Make support
easily discoverable from the Support URL and verify the contact channel works.
Update the privacy page's diagnostic-log section to describe manual Start/Stop,
disconnected Start and capture disabled after relaunch. Clarify that Watch is not
included in the first iPhone beta. HTTP 200 confirms retrieval, not legal approval
or that a contact channel accepts messages. This repository does not deploy or
change the website.

## Validation and submission sequence

Apple's requirements checked on 2026-09-05 require the iOS 26 SDK or later for
uploads since 2026-04-28. This preparation uses the iOS 26.5 SDK. External beta
testing also needs test information, a feedback address and potentially Beta App
Review. These are separate from passing local build and UI checks.
Sources: [SDK requirements](https://developer.apple.com/news/?id=ueeok6yw),
[TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview),
[App Privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).

1. Run `.xcodegen/generate-local.sh` and the applicable commands in
   [testing.md](../testing.md). Keep signing data and build outputs untracked.
2. Validate the source resources and generated schemes:
   `python3 scripts/validate-app-store-resources.py`.
3. Archive the FENR scheme for a generic iOS device using Release in Xcode, or:

   ```sh
   xcodebuild -project FENR.xcodeproj -scheme FENR -configuration Release \
     -destination 'generic/platform=iOS' -archivePath /tmp/FENR-AppStore.xcarchive archive
   python3 scripts/validate-app-store-resources.py --archive /tmp/FENR-AppStore.xcarchive
   ```

4. Complete [the iPhone QA matrix](qa-iphone.md) on iPhone 17, iPhone 17 Pro and
   iPhone SE 3 at default text size, with independent visual review of each fix.
   In Simulator, inspect the support row in portrait and landscape, open the
   link, return to Settings, and verify demo entry without location access.
   Exercise navigation in Madrid, New York, and Tokyo or Sydney. Check existing
   no-location, offline, and unavailable-route states. Use synthetic locations.
5. In Organizer, validate and distribute the archive to App Store Connect with
   the intended distribution account. A locally signed archive still needs
   distribution signing and Apple's server-side validation; an unsigned archive
   is only a local packaging check and cannot be uploaded as-is.
6. Supply the coverage file, Support URL, review notes, contact details,
   screenshots, accurate hardware/firmware compatibility, and App Privacy
   answers. Resolve the website copy/contact and placeholder-link findings before submission.
7. Check processing messages for missing API declarations and metadata errors.
   Submit for review only once the website and remaining metadata are complete.

The owner reported physical traction-control and bike-lock testing on 2026-09-05.
No tested-firmware inventory or new instrumented captures accompany that report.
Keep the vehicle gates and exact confirmation rules unchanged. Simulator/demo
verification remains separate from this owner report and cannot extend it to
other hardware or firmware.

Local metadata validation covers file format and field constraints only. It does
not validate remote App Privacy answers, review contacts, agreements, distribution
eligibility or beta-review approval. The current local source manifests describe
UserDefaults reasons; assess developer data collection separately, including
user-submitted support material and Apple's TestFlight diagnostics.
