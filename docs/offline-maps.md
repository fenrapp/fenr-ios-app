# Offline maps

The navigation map selector has independent source and appearance choices.
Normal (the default for existing settings) uses Apple Maps. Offline uses Mapbox
Maps SDK 11.30.1 and the shared downloaded regions. Both sources support the
standard/topographic and satellite appearances, plus Focus during active
navigation. The map-free Focus renderer stays local. Watch does not link Mapbox.

Standard is the initial appearance when no choice has been saved. Explicit
Focus, Standard and Satellite preferences survive reopening navigation and relaunch.
The selected source is persisted independently of the Focus/standard/satellite
preference. It applies to the home map, previews, recording, GPX, calculated road
routes and the minimap; selecting a destination never overrides it. Changing
source preserves the route, recording and current camera. The same selector
exposes offline downloads and coverage status. Offline uses topographic as a
temporary fallback when satellite is not downloaded, retaining the satellite
preference. Download coverage is checked even when connected.
The navigation map-source control highlights Offline with a blue download icon;
coverage text stays in its selector instead of floating over the map. The home
planning card has a full-width downloads row and no duplicate map-source control.

Offline selects the map source, not the device network state: Mapbox can still
fetch missing map resources while connected. Search and road-route calculation
continue to use Apple services and require a connection with either map source.

## Configuration

The public runtime token is read from `MBXAccessToken` in the application plist.
`config/Mapbox.xcconfig` optionally includes `.xcodegen/Mapbox.xcconfig`, which is
ignored by Git. Create that local file with:

```xcconfig
MAPBOX_ACCESS_TOKEN = <public Mapbox token>
```

Use a dedicated `FENR iOS` public token with `styles:tiles`, `styles:read` and
`fonts:read`. Do not grant secret/admin scopes or web-only URL restrictions.
Never commit credentials or resolved plist values. The CI workflow reads the repository secret
`MAPBOX_ACCESS_TOKEN` into the ignored local override when it is configured; keep command expansion and
build logs out of public artifacts. Any SDK download credential, if required by
the build environment, is separate and belongs only to that build environment.
The pinned SPM package and resolved dependency revisions are checked in.
Regenerate with `.xcodegen/generate-local.sh` to preserve local signing.

## Behavior and ownership

`OfflineMapsDomain` defines geometry, requests, availability and repository
contracts. `OfflineMapsData` owns the versioned catalog, connectivity, storage
checks and one download queue. `RideNavigationMapbox` implements the presentation
contracts; views receive FENR presentation values. App composition shares one
service, TileStore and OfflineManager across settings and navigation.

Downloads require an explicit action, use Wi-Fi by default, and pause when the
app leaves the foreground. Returning to the foreground resumes interrupted
work on an allowed network; manually paused work stays paused. Topographic and
satellite layers complete independently. The SDK stores outdoors-v12 and
satellite-streets-v12 resources for zoom levels 0 through 16. A saved GPX alone
does not imply downloaded map coverage.

Area selection uses a full-screen map with native pan and pinch. A blue outline
marks the exact rectangle passed to the download estimate; the area outside it
is dimmed. Controls sit below the rectangle in portrait and beside it in
landscape. Existing coverage is outlined separately.
After selecting an area, a separate native form confirms the name, layers,
network policy and estimate. Editing the name does not resize the map. Returning
to the map preserves the name and refreshes the selection for the current viewport.
Area details use a full-screen map with a bottom panel in portrait and a side
panel in landscape. The main action remains visible while details scroll;
renaming, manual updates and deletion are grouped in the toolbar menu.
Download states explain network waits and show each layer's actual availability.
Library rows use Mapbox snapshots with the selected coverage and provider attribution.
Snapshots are cached in Library/Caches/OfflineMapThumbnails, refreshed when a layer
completes or updates, and cancelled when their row disappears. Old revisions are
removed when replaced. These disposable previews do not establish offline coverage.
Swipe left on an area for Update (when ready) and Delete; deletion requires confirmation.
Large accessible text switches storage statistics and row content to a vertical layout.

A rectangle crossing the antimeridian is split. GPX selection uses conservative,
overlapping strips around each connected segment; it never bridges disconnected
segments or downloads a single bounding rectangle around an entire winding
route. Coverage checks the union of completed rectangles, including interior
gaps. Unsupported polar latitudes are clipped to Web Mercator's limits.

Downloads and the catalog live in Application Support/OfflineMaps, excluded
from device backups. The startup reconciliation checks actual resources before
reporting availability. Updates download into a replacement region and retain
the last completed resource until the replacement is saved. Deleting a GPX
leaves maps intact; deleting an area leaves the GPX intact. Mapbox can reclaim
shared resources later, so the library reports measured allocated storage.
FENR reserves 1 GB and surfaces provider tile-pack limits instead of evicting
ready areas automatically. A 30-day reminder invites a manual update; it does
not make downloaded maps expire.

The explicit Follow GPX action skips road calculation, even far from the track.
A line pointing toward a GPX is orientation, not a calculated traversable road.
Search, road approaches and road exits still need network access. The map
receives FENR's existing position samples and does not create a second GPS or BLE
session.

## Attribution and privacy

Mapbox's wordmark and attribution control remain on map surfaces, including
mini maps and Focus with a base map. The attribution control exposes Mapbox's
telemetry opt-out. The offline library explains the provider and links to its
privacy policy. The SDK may send de-identified location and usage data when the
host app gathers it; do not describe this integration as collecting no data.
Downloaded region requests also contact Mapbox. Disk capacity is used locally
for display and download admission, with required-reason declarations in the
OfflineMapsData privacy manifest.

Before distribution, reconcile the public FENR privacy policy and App Store
privacy answers with this SDK and its bundled manifests. This implementation
does not publish legal pages or submit an Apple build.

Official references:

- [SDK attribution and telemetry](https://docs.mapbox.com/ios/maps/guides/)
- [Mapbox privacy policy](https://www.mapbox.com/legal/privacy)
- [Offline resources](https://docs.mapbox.com/ios/maps/guides/offline/)
- [Apple disk-space API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

## Verification

Run the checks in `docs/testing.md`, including OfflineMapsDomainTests,
OfflineMapsDataTests and RideNavigationTests. Test a clean application launch
without network access after explicit downloads; incidental map cache is not
offline acceptance evidence. Check both layers, partial coverage, leaving an
area, manual pause, network changes, relaunch, update failure, storage pressure,
Focus and minimap. Exercise iOS 17.5, compact and current iPhones, landscape,
light/dark appearance and accessible text sizes.

A physical iPhone test with mobile data and Wi-Fi disabled is required before
claiming real-device offline validation. Simulator and automated test results
must be reported separately. TestFlight publication is outside this change.

## Local implementation checks

The September 19 cleanup passed 221 tests across SettingsDomain, SettingsData,
RideNavigation, OfflineMapsDomain and OfflineMapsData. Focused regression tests
cover Standard defaults and saved styles, serialized library actions, duplicate
area actions, cancellation, late completions, and reopening a selector with an
interrupted estimate. Reminder tests cover 29, 30 and 31 days while retaining
downloaded layer availability. Strict SwiftLint and architecture validation passed.
Debug and Release simulator builds and their runtime framework checks passed.
The 13 settings and offline lifecycle regression tests also passed on iOS 17.5.

The library and real map previews were inspected in the iPhone 17 simulator on
iOS 27 in portrait and landscape. Native swipe actions were exercised. The
compact iPhone SE on iOS 17.5 was inspected in dark appearance with accessible
text, including the revised storage layout. Temporary presentation hooks used
for inspection were removed from the delivered source.

Earlier implementation checks covered Debug and Release iPhone and Watch bundles,
with runtime framework validation and no Mapbox images in Watch. The full iPhone
suite passed 1,626 tests; offline/domain/navigation tests passed on iOS 17.5
(137 tests). Visual checks covered selection, download options, landscape software
keyboard, per-layer details and the attribution/privacy menu. Synthetic areas
completed explicit topographic and satellite downloads and remained ready after
relaunch.

These checks do not establish cold-launch behavior with network and incidental
cache disabled. That acceptance check and physical iPhone offline validation remain
pending. Public privacy declarations and the CI repository secret must be reviewed
or configured before distribution.

The landscape library regression was corrected by letting the native List occupy
its full container width instead of constraining the scroll view to 640 points.
The navigation bar and scroll-edge effect now share the full screen width.
The Mapbox selector aligns the native wordmark with the bottom-aligned info glyph
inside the SDK's larger tap target, retaining the SDK attribution/privacy action.
The landscape scroll and area-detail ornaments were visually inspected on iPhone 17.
