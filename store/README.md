# App Store and TestFlight

Release assets and ASC commands for **FENR - Unleash your varg**.
App ID: `6808795194`. Bundle ID: `in.fenr.app`. The `FENR` scheme includes
both iPhone extensions and the read-only Apple Watch companion.

## Files

| Path | Contents |
| --- | --- |
| `metadata/` | English App Store listing in ASC JSON format. |
| `screenshots/<version>/en-US/iphone69/` | Final iPhone screenshots. |
| `screenshots/<version>/en-US/watch46/` | Final Apple Watch screenshots. |
| `testflight/<version>/en-US/` | Beta description and build-specific What to Test notes. |
| `copyright.txt` | Public copyright text. |
| `artifacts/<version>/<build>/` | Ignored archives, exports and release evidence. |

See [Testing](../docs/testing.md) for checks, [App Store resources](../docs/app-store/README.md)
for archiving and privacy, and the [reviewer guide](../docs/app-review-demo.md)
for demo access and review instructions.

## Setup

Run commands from the repository root. Examples use ASC 5.3.3; check
`asc <command> --help` after upgrading. Install with `brew install asc` and
configure an existing keychain profile with `asc auth login --help`.

```sh
FENR_ASC_PROFILE='<existing-keychain-profile>'
FENR_APP_ID='6808795194'
FENR_VERSION='<marketing-version>'
FENR_BUILD='<unused-build-number>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth apps list --bundle-id in.fenr.app
```

Verify the app ID before writing. Keep credentials, signing settings and the
Mapbox token in ignored local configuration, as described in
[Offline maps](../docs/offline-maps.md). Never commit binaries or private contacts.
The review contact phone number stays only in App Store Connect, including when
collecting API responses or logs. Do not enable sensitive/debug API logging.

## Listing and screenshots

Create the next version with `asc versions create` when needed, selecting
`--release-type MANUAL` and the copyright from `copyright.txt`. Prepare its
metadata, screenshots and TestFlight text locally before uploading.

```sh
python3 scripts/validate-app-store-resources.py
asc metadata validate --dir store/metadata
asc --profile "$FENR_ASC_PROFILE" --strict-auth metadata push \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --platform IOS --dir store/metadata --dry-run
```

Review the proposed changes, then repeat without `--dry-run`. Run the preview
again afterwards: adds, updates and deletes should be empty. Omitted fields stay
unchanged. Prices, territories and declarations are managed separately in Apple.

Preserve the final supplied image files. Use numeric filename prefixes for order
and keep only final images in each upload directory. The 1.2 assets contain ten
iPhone images at 1320x2868 and two Watch images at 416x496.

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth screenshots upload \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --path "store/screenshots/$FENR_VERSION" \
  --device-type IPHONE_69 --skip-existing --dry-run
```

Repeat with `--device-type WATCH_SERIES_10` for the Watch set. Remove `--dry-run`
to upload. To replace a set, preview `--replace --dry-run`, then use
`--replace --confirm`. After uploading, use `asc screenshots list` to verify
order, file checksums and `assetDeliveryState: COMPLETE`. Use `--resume` after
an interrupted screenshot upload.

## Build and TestFlight

Commit the intended source before archiving. Record the source SHA, platform,
version, build number and build-setting overrides in ignored release evidence.
Follow the [archive workflow](../docs/app-store/README.md), then validate the
exported iPhone app, extensions and Watch companion. Verify the runtime Mapbox
token is present in the exported iPhone app and absent from tracked files.

```sh
FENR_IPA='<local-path-to-exported-FENR.ipa>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds upload \
  --app "$FENR_APP_ID" --ipa "$FENR_IPA" --version "$FENR_VERSION" --build-number "$FENR_BUILD"
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds wait \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --build-number "$FENR_BUILD" \
  --platform IOS --fail-on-invalid
```

After an interrupted upload, inspect `asc builds uploads` and `asc builds list`
before retrying. `builds upload --dry-run` reserves remote upload operations;
it is not a read-only check. Never reuse a build number for a different binary.

After Apple confirms receipt, create and push the annotated tag
`apple/ios/<version>-build.<number>` on the exact archived source commit.
Include version, build number, source SHA, Apple build/upload ID and build-setting
overrides in the annotation. Keep signing values and credentials out of it.

Once processing is `VALID`, use the returned build ID to publish its notes:

```sh
FENR_BUILD_ID='<processed-build-resource-id>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds test-notes create \
  --build-id "$FENR_BUILD_ID" --locale en-US \
  --whats-new "$(cat "store/testflight/$FENR_VERSION/en-US/whats-new.txt")"
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds test-notes list --build-id "$FENR_BUILD_ID"
```

Use `builds test-notes update` if notes already exist. Keep the shared beta
app description in sync with `description.txt` using `testflight app-localizations`.
Read the published build notes back and compare them with the committed text.

Choose the intended existing group from `testflight groups list --app`, then
use `builds add-groups --build-id ... --group ...`. External distribution may
require `testflight review submit --build-id ... --confirm`. Do not create
new testers or public links as a side effect. Verify group membership and
`builds build-beta-detail view` before announcing availability: `VALID` alone
does not mean external testers can install the build. Verify the remote release
tag still resolves to the archived source SHA.

## App Store review and release

TestFlight distribution does not submit or release the public App Store version.
Reuse the processed build when preparing that version:

```sh
FENR_VERSION_ID='<app-store-version-resource-id>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth versions attach-build \
  --version-id "$FENR_VERSION_ID" --build-id "$FENR_BUILD_ID"
asc --profile "$FENR_ASC_PROFILE" --strict-auth validate \
  --app "$FENR_APP_ID" --version-id "$FENR_VERSION_ID" --strict
```

Review the listing, screenshots, privacy and age-rating answers, export compliance,
agreements and manual release setting. Use **Explore demo > Start demo** in review
notes; no motorcycle or account is required. Generate the reviewer PDF with
`scripts/render-review-document.py` and the dependencies in
`scripts/asc-pdf-requirements.txt`, inspect it, then upload via `review attachments-upload`.
Skip matching delivered attachments and verify their checksums and delivery state.
If routing coverage is missing, upload `docs/app-store/routing-coverage.geojson`
with `routing-coverage create` for the version.

Only submit with `asc review submit --confirm` when explicitly authorized.
After approval, `asc versions release --confirm` publishes a version in
`PENDING_DEVELOPER_RELEASE`; that is a separate authorized action.
