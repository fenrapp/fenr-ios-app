# App Store resources

The production `FENR` scheme packages the iPhone app with Share and Live Activity
extensions. The Watch app is built separately and is not embedded in the first
iPhone distribution.

[store/README.md](../../store/README.md) contains the maintained ASC workflow,
listing metadata, screenshots and upload commands. The
[demo guide](../app-review-demo.md) is the source for reviewer notes and the PDF.
Build and test commands are in [Testing](../testing.md).

## Repository resources

| Resource | Purpose |
| --- | --- |
| `routing-coverage.geojson` | Worldwide routing coverage for Xcode and App Store Connect. |
| `App/Resources/Shared/PrivacyInfo.xcprivacy` | App-level required-reason API declarations. |
| Framework `PrivacyInfo.xcprivacy` files | API declarations owned by the framework using the API. |
| `store/metadata/` | Public English listing text. |
| `store/screenshots/` | Final owner-supplied screenshots, kept in upload order. |

XcodeGen's post-generation hook attaches the coverage file to `FENR` and
`FENRDebug`. It does not simulate GPS or bundle the GeoJSON into the app.
Road directions depend on Apple Maps availability and connectivity; the world
boundary does not promise offline or off-road routing.

## Validate and archive

From the repository root, generate the project using the
[development instructions](../development.md), then run:

```sh
python3 scripts/validate-app-store-resources.py
xcodebuild -project FENR.xcodeproj -scheme FENR -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/FENR-AppStore.xcarchive archive
python3 scripts/validate-app-store-resources.py --archive /tmp/FENR-AppStore.xcarchive
```

Device archives require your own signing configuration. Keep credentials,
profiles, exported binaries and reviewer contact details out of Git. Source and
archive validation check packaging; distribution signing and Apple's processing
are separate steps. Use the ASC workflow for uploading, review and release.

## Public copy

Keep listing text aligned with supported firmware, the iPhone-only distribution,
the simulated demo and manual diagnostic capture. Settings exposes
[Support](https://fenr.to), [Privacy Policy](https://fenr.to/privacy) and
[Terms of Use](https://fenr.to/terms). Verify those destinations and the current
App Store declarations when preparing a release. Historical QA reports and
per-build evidence belong outside the public repository.
