# iPhone TestFlight QA

## Required matrix and completion rules

iPhone 17 is the visual reference. Repeat the end-to-end flows on iPhone 17 Pro
and iPhone SE (3rd generation), at the system default text size only. In simctl,
the default category is named `large`; it does not mean an enlarged text setting.
Read and record this value before each run without changing it.

Use the candidate build and record its source revision, local changes, bundle ID,
version/build, runtime, device, appearance and orientation. A previous installation
is baseline evidence only and cannot pass a candidate check. Use synthetic demo
data; do not capture real motorcycle identifiers or private diagnostics.

Each required cell needs functional execution and independent visual review.
`Pending` means the candidate has not been verified. Unit tests, previews and
static inspection alone do not pass an end-to-end cell. Simulator evidence does
not establish physical BLE, vehicle writes or actual device background behavior.

| Flow and required states | iPhone 17 | iPhone 17 Pro | iPhone SE 3 |
| --- | --- | --- | --- |
| First launch, onboarding, setup validation, permissions denied, demo introduction/start/exit | Pending | Pending | Pending |
| Startup progress, storage failure/retry, demo failure/retry, relaunch | Pending | Pending | Pending |
| Dashboard disconnected/connecting/retry, portrait rotation notice, both landscape orientations | Pending | Pending | Pending |
| Riding dashboard, all enabled cards/pages, compact speed, indicators, temperatures, long values, reconnect | Pending | Pending | Pending |
| Charging, both sliders and extremes, unavailable/busy/success/error, waiting, balance/full charge, riding transition | Pending | Pending | Pending |
| Settings, card preferences, units, power/regen/traction controls and unavailable/confirmation states | Pending | Pending | Pending |
| Bike lock availability, setup, PIN creation/mismatch/confirmation/entry, cancel, busy/error/locked/unlocked | Pending | Pending | Pending |
| Diagnostics, manual Start/Stop, disconnected Start, reconnect while capturing, history/detail/export/delete, empty/error | Pending | Pending | Pending |
| Battery health, loading/missing/partial/populated/error states and detail navigation | Pending | Pending | Pending |
| History and maintenance, empty/populated/detail/edit/save/cancel/delete, keyboard and validation feedback | Pending | Pending | Pending |
| Navigation home/search/import/preview, route alternatives, denied location/offline/no route, save failure/retry | Pending | Pending | Pending |
| Active navigation/recording/pause/resume/finish/summary, map selectors, Focus controls, arrival and confirmations | Pending | Pending | Pending |
| Mini map drag/resize/orientation/expand, dashboard/settings coexistence and return to navigation | Pending | Pending | Pending |
| Share/export sheets, incoming destination, external links, foreground/background and return navigation | Pending | Pending | Pending |

For portrait screens, verify keyboard presentation and every supported rotation.
For the landscape dashboard, verify both left and right safe areas. Check light
and dark appearance where supported. Text-size variants are outside this required
matrix and must not be substituted for default-size coverage.

## Visual acceptance and correction loop

- No unintended overlap, clipped values/units, hidden primary actions, controls
  beneath system areas, or inactive overlays intercepting taps.
- Essential labels, error messages and feedback remain readable. Long secondary
  content may truncate only if its full value remains accessible.
- Preserve clear hierarchy, consistent spacing/alignment and effective touch
  targets of at least 44 points. Adapt grouping, available space or scrollable
  detail content instead of scaling the entire screen down.
- An intentionally movable mini map must remain draggable and recoverable, and
  underlying required actions must remain reachable by moving/minimizing it.
- The executing agent records reproduction steps and a before capture. A separate
  design reviewer evaluates the image and reports specific visible defects.
- Correct each confirmed defect, rebuild, rerun its scenario, capture the result
  and obtain independent review. Repeat affected-component checks on all three
  devices before closing the finding.
- Final acceptance requires all required cells to pass with no unresolved defect
  affecting base-size layout or behavior. Record blocked scenarios explicitly;
  never replace missing evidence with an assumption of success.

## Current acceptance status

The full release matrix above remains incomplete. The temporary UI-test targets,
schemes and injected QA scenarios were removed at the owner's request on
2026-09-06. Future end-to-end checks are manual using the native Debug emulator
and public production demo. Keep unavailable states pending; the retained unit
tests do not establish their end-to-end acceptance.

## Historical cleanup evidence

The following results precede that harness removal. The cleanup correction run
passed these focused scenarios at unchanged iOS default text size on iOS 26.5:

| Cleanup regression | iPhone 17 | iPhone 17 Pro | iPhone SE 3 |
| --- | --- | --- | --- |
| Recording, pause/resume, mini-map drag/rotate/resize/expand, finish cancellation, keyboard editing, exact named save, share and relaunch | Pass | Pass | Pass |
| Power, regeneration, traction and regen-traction changes with confirmed changed values and reachable controls | Pass | Pass | Pass |
| Map and traction write errors with visible feedback, enabled recovery and preserved prior values | Pass | Pass | Pass |

The three result bundles are `cleanup-iphone17-ui-verified.xcresult`,
`cleanup-pro-ui-verified.xcresult` and `cleanup-se-ui-verified.xcresult` under
ignored `build/testflight-qa/`; each contains three passing tests and 18 screenshots.
`cleanup-diagnostics-ui.xcresult` adds two passing manual-capture tests on iPhone 17
and 12 reviewed screenshots.

A final review found the altitude value clipped in the SE navigation header.
Removing the header's minimum text width and preserving the altitude's intrinsic
width fixed it. The full navigation flow was rebuilt and repeated on all three
models in `cleanup-{iphone17,pro,se}-navigation-altitude.xcresult`: one passing
test and 12 screenshots per model. Recording, paused and expanded states now
show the complete value and unit. A separate reviewer inspected these nine
full-device images individually and confirmed legible titles and separated
controls. Production Release was rebuilt successfully.
Power/error and diagnostics results above precede this final header-only change;
they are not represented as a full run of a later candidate. The local
`cleanup-candidate.json` identifies that run's executable and Swift snapshot.

The mini-map interaction and default orientation-button overlap, summary keyboard
focus loss, and test harness failures were reproduced and corrected. The former
harness targeted real slider accessibility elements, used native list scrolling,
selected the actual text-edit menu item and required an exact saved name. These
scenario passes do not establish full-row coverage, both appearances/orientations,
production-demo acceptance or physical vehicle behavior.

The local Release archives validate packaging only. They are unsigned and must
be rebuilt after production changes. Their resource checks do not prove UI
correctness, distribution signing, an unused build number or Apple acceptance.
No build has been uploaded in this preparation.

Keep per-run notes, hashes, screenshots, videos and result bundles in ignored
`build/testflight-qa/`. Earlier execution diaries are preserved there under
`cleanup-history/`. Some earlier full result bundles were removed during disk
recovery; retained screenshots and logs are historical evidence only. A missing
bundle must never be cited as a retained or current passing result.

Before release, record one source-frozen candidate's complete matrix, independent
visual review and physical-device limitations. See [testing.md](../testing.md)
for current manual test instructions and [validation.md](validation.md) for the
separate metadata, website and packaging checklist.


## Historical navigation margin follow-up

The earlier visual review missed the SE panels reaching the screen edges despite
an outer padding declaration. Intrinsic metric/action widths and redundant row
spacing could enlarge the whole navigation overlay beyond its proposed width.
That correction measured the complete action row and used two rows when needed,
with no font or control-size reduction.

`navigation-margins-{iphone17,pro,se}-final.xcresult` each contains a passing full
recording/pause/mini-map/save/share/relaunch test and 13 screenshots. Tests assert
that the header, dashboard and paused guidance surfaces remain inside a screen
rectangle inset by 16 points; control visibility and non-overlap checks remain.
Independent inspection confirmed 32-pixel margins on the SE's 2x captures,
including the top and bottom edges. The other models retain safe-area spacing.
The run reaches both interface landscape orientations: initial recording/paused
and the opposite orientation after expansion. The two paused captures must not
be described as opposite interface orientations solely from device-orientation
argument names.

Strict lint, Debug QA build and production Release simulator build passed.
The run's source/executable fingerprint is in ignored
`build/testflight-qa/navigation-margins-candidate.json`. This focused correction
does not complete the broader release matrix above.

## Historical compact navigation controls follow-up

The margin correction made the SE footer unnecessarily tall when paused. The
dashboard now selects a compact action row by available width: Mini uses its
existing icon and accessible label, while Pause/Resume and Finish keep their
text, icons and typography. Recording and paused states use the same compact
variant. Larger phones retain the Mini text. A stacked fallback remains for
content that cannot fit either row; no enlarged-text validation was performed.

`compact-navigation-{iphone17,pro,se}.xcresult` each contains one passing full
recording/pause/mini-map/save/share/relaunch test and 13 screenshots on iOS 26.5
with unchanged default text. The regression checks that metrics and action
centers share a single row, all three action targets are at least 44 points in
both dimensions, and the existing 16-point surface margins remain intact.
Independent visual review of recording, paused and expanded states confirmed
the compact SE row and the full controls on iPhone 17 and 17 Pro. These focused
results do not complete the broader release matrix.

Strict lint, Debug QA build and production Release simulator build passed.
That run's source and executable hashes are retained in ignored
`build/testflight-qa/compact-navigation-candidate.json`; screenshots and result
bundles also remain outside Git. No build was uploaded.

The subsequent Recording Ride header polish adds 4 points of internal padding
on every side using the existing DesignSystem token. The full navigation test
passed again on all three models in `header-padding-{iphone17,pro,se}.xcresult`
with default text, retaining 13 screenshots per model. Header copy remains
complete and the footer retains its single row and 16-point exterior margins.
Debug QA and production Release builds, strict lint and whitespace checks passed.
That run's fingerprint is `build/testflight-qa/header-padding-candidate.json`.

A subsequent code/file cleanup removed an unused calibration binding and two
imports from the production factory and corrected reconnect guard indentation.
UI source and behavior are unchanged from the header-padding run. All 84 app
tests passed in `final-hygiene-app-tests.xcresult`; Debug QA, iOS Release,
Watch Release, strict lint, resource validation and four review-document tests
also passed. The UI matrix was not rerun for these nonvisual edits.
Generated caches and obsolete build products were removed; current products and
all retained QA evidence remained available at that stage. The local deletion inventory and
that stage's fingerprint are `build/testflight-qa/final-hygiene-deletions.json` and
`build/testflight-qa/final-hygiene-candidate.json`.
