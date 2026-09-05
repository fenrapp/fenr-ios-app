# App Store and TestFlight with ASC

Use ASC directly from the repository root. These commands were verified with
[ASC 4.11.0](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/4.11.0).
Use `asc <command> --help` when updating ASC. There is no custom release CLI.

FENR - Unleash your varg is an iPhone app for compatible Stark Varg motorcycles.
App ID: `6808795194`. Bundle ID: `in.fenr.app`. The FENR scheme includes the Share
and Live Activity extensions; the Watch app is a separate submission.

## Files and local setup

- `metadata/`: canonical ASC JSON for the English App Store listing.
- `copyright.txt`: public copyright text.
- `testflight/<version>/en-US/`: beta description and What to Test text.
- `screenshots/<version>/en-US/iphone69/`: final owner-supplied screenshots.
- [Reviewer guide](../docs/app-review-demo.md): source for the PDF and review notes.
- [Submission checklist](../docs/app-store/README.md): privacy, legal and release checks.

Install ASC from its official releases or with `brew install asc`. Credentials
stay in the macOS keychain. Use `asc auth login --help` to configure a profile if
needed. Keep checkout-specific profile metadata in the ignored `.asc/config.json`.
Select your existing profile locally; never put keys or private contacts in Git.

```sh
export ASC_CONFIG_PATH="$PWD/.asc/config.json"
FENR_ASC_PROFILE='<existing-keychain-profile>'
FENR_APP_ID='6808795194'
FENR_VERSION='1.0'
FENR_BUILD='1'
asc --profile "$FENR_ASC_PROFILE" --strict-auth apps list --bundle-id in.fenr.app
```

Check that the returned app ID matches before making changes. The examples below
use this explicit profile. Keep debug/API logging and `--include-sensitive` out of
shared output. `.asc/`, `store/private/`, `store/artifacts/` and signing files are
ignored. Set private review contacts and TestFlight feedback email in App Store
Connect; they do not need a public configuration file.
The review contact phone number must stay only in App Store Connect. Do not save
it anywhere in this checkout, including ignored configuration, API responses or
logs.

## Validate, preview and upload the listing

```sh
asc metadata validate --dir store/metadata
asc --profile "$FENR_ASC_PROFILE" --strict-auth metadata push \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --platform IOS --dir store/metadata --dry-run
asc --profile "$FENR_ASC_PROFILE" --strict-auth metadata push \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --platform IOS --dir store/metadata
```

Repeat the dry run after uploading: adds, updates and deletes should be empty.
Omitted fields are unchanged. The initial release has no What's New field;
add `whatsNew` to the version JSON for subsequent App Store releases. Prices,
territories, categories and declarations are managed separately in Apple.

Retrieve the version resource ID, then set the copyright and manual release policy:

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth versions list \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --platform IOS
FENR_VERSION_ID='<version-resource-id-from-the-list>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth versions update \
  --version-id "$FENR_VERSION_ID" --copyright "$(cat store/copyright.txt)" --release-type MANUAL
```

For a new version, use `asc versions create --help`, create its local metadata and
TestFlight directories, and supply new screenshots. Confirm app and extension
versions match before building. Use a unique build number for each new binary.

## Reviewer PDF and notes

The reviewer uses **Explore demo > Start demo**, without a motorcycle or account.
The generator exports the canonical reviewer instructions. Python 3.9+ is required; install the PDF dependencies locally once:

```sh
python3 -m venv .asc/venv
.asc/venv/bin/python3 -m pip install -r scripts/asc-pdf-requirements.txt
FENR_REVIEW_DIR="store/artifacts/$FENR_VERSION/$FENR_BUILD"
.asc/venv/bin/python3 scripts/render-review-document.py \
  --source docs/app-review-demo.md --output-dir "$FENR_REVIEW_DIR" \
  --version "$FENR_VERSION" --build "$FENR_BUILD"
```

Inspect the PDF before uploading. Get the review detail ID, then update its notes:

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth review details-for-version --version-id "$FENR_VERSION_ID"
FENR_REVIEW_ID='<review-detail-id>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth review details-update \
  --id "$FENR_REVIEW_ID" --demo-account-required=false --notes "$(cat "$FENR_REVIEW_DIR/review-notes.txt")"
asc --profile "$FENR_ASC_PROFILE" --strict-auth review attachments-list --review-detail "$FENR_REVIEW_ID" --paginate
asc --profile "$FENR_ASC_PROFILE" --strict-auth review attachments-upload \
  --review-detail "$FENR_REVIEW_ID" --file "$FENR_REVIEW_DIR/FENR-review.pdf"
```

If there is no review detail yet, use `review details-create --version-id` with the
same notes flags. Before uploading, skip an already delivered PDF with the same
checksum (`md5 -q "$FENR_REVIEW_DIR/FENR-review.pdf"`). Check `attachments-list`
after uploading for matching `sourceFileChecksum` and `assetDeliveryState: COMPLETE`.
Replace obsolete documents only after confirming the new one has been delivered.

Use `asc routing-coverage view --version-id "$FENR_VERSION_ID"` with the same profile
to inspect coverage. If absent, upload the versioned source:

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth routing-coverage create \
  --version-id "$FENR_VERSION_ID" --file docs/app-store/routing-coverage.geojson
```

## Screenshots supplied by the owner

Version 1.0 includes ten final English screenshots at 1320x2868. Their `01` to `10`
filename prefixes define the upload order; the repository copies preserve the
owner-supplied PNG bytes.

Do not generate, resize or edit screenshots. Supply 1-10 opaque PNG/JPEG files in
the supported iPhone 6.9-inch dimensions. Name them `01-...`, `02-...`, etc. for
explicit upload order. Keep only final images in each upload directory.

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth screenshots upload \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --path "store/screenshots/$FENR_VERSION" \
  --device-type IPHONE_69 --skip-existing --dry-run
```

Remove `--dry-run` to upload. ASC provides `--resume` for interrupted uploads.
For an intentional replacement, preview `--replace --dry-run` before using
`--replace --confirm`. Inspect the remote order and delivery state afterwards.
Missing screenshots do not prevent metadata updates or TestFlight uploads.

## Build and TestFlight

Archive and export the FENR scheme using the [existing Xcode workflow](../docs/app-store/README.md).
Keep distribution signing private; resolve Xcode account/profile errors locally.
Validate the exported app and both extensions before uploading. Uploading and
processing a build do not submit the App Store version for review.

```sh
FENR_IPA='<local-path-to-exported-FENR.ipa>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds upload \
  --app "$FENR_APP_ID" --ipa "$FENR_IPA" --version "$FENR_VERSION" --build-number "$FENR_BUILD"
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds list \
  --app "$FENR_APP_ID" --version "$FENR_VERSION" --build-number "$FENR_BUILD" --processing-state all
FENR_BUILD_ID='<processed-build-resource-id>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth testflight app-localizations list --app "$FENR_APP_ID"
FENR_BETA_LOCALE_ID='<en-US-beta-localization-id>'
asc --profile "$FENR_ASC_PROFILE" --strict-auth testflight app-localizations update \
  --id "$FENR_BETA_LOCALE_ID" --description "$(cat "store/testflight/$FENR_VERSION/en-US/description.txt")" \
  --marketing-url https://fenr.to --privacy-policy-url https://fenr.to/privacy
asc --profile "$FENR_ASC_PROFILE" --strict-auth builds test-notes create \
  --build-id "$FENR_BUILD_ID" --locale en-US \
  --whats-new "$(cat "store/testflight/$FENR_VERSION/en-US/whats-new.txt")"
```

Use `testflight app-localizations create --app ... --locale en-US` if the beta
localization is absent, and `builds test-notes update` if notes already exist.
After an interrupted upload, inspect builds and processing before retrying; do
not upload a duplicate. `builds upload --dry-run` reserves remote upload operations
and must not be used as a read-only check.

Choose existing groups with `testflight groups list --app`, then use
`builds add-groups --build-id ... --group ...` with the explicit profile. External
TestFlight distribution requires complete beta review information and may require
`testflight review submit --build-id ... --confirm`. Beta review is separate from
App Store review. Never create testers or enable public links as an upload side effect.

## Attach, review and publish separately

Reuse the processed TestFlight build for the App Store version:

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth versions attach-build \
  --version-id "$FENR_VERSION_ID" --build "$FENR_BUILD_ID"
asc --profile "$FENR_ASC_PROFILE" --strict-auth validate --app "$FENR_APP_ID" --version-id "$FENR_VERSION_ID" --strict
```

Complete the [submission checklist](../docs/app-store/README.md), contact, screenshots,
privacy and age-rating answers, rights, export compliance and agreements before
submission. Recheck the build, public texts, PDF and manual release setting.
Only when explicitly requested:

```sh
asc --profile "$FENR_ASC_PROFILE" --strict-auth review submit \
  --app "$FENR_APP_ID" --version-id "$FENR_VERSION_ID" --build-id "$FENR_BUILD_ID" --confirm
# After approval, while PENDING_DEVELOPER_RELEASE:
asc --profile "$FENR_ASC_PROFILE" --strict-auth versions release --version-id "$FENR_VERSION_ID" --confirm
```
