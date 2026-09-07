# Modernization QA report

Report date: 2026-09-07. Phases 0-11 are complete on `chore/project-modernization`. Final code `5895cb36` passed the regression and E2E matrix, including seven E2E scenarios on each fresh iPhone simulator; visual QA passed. Production remains identical to `30c8e6cc`. The branch is ready for review and has not been merged into main. The latest physical iPhone installation remains pending because the device connection is unavailable.

## Scope and provenance

- Work branch: `chore/project-modernization`, based on `main` at `7f393cfd`.
- Production code under final QA: `30c8e6cc`, including the scoped fixes `036f7d5a` and `41f59f82`. Test-only commit `5895cb36` adds recovery from the first-use keyboard overlay; it does not change production code. No merge into main is claimed.
- Sources: `/tmp/fenr-modernization/PROGRESS.md`, read-only Git history, actual xcresult top-level summaries, build/lint logs, validator JSON, and the current E2E test sources.
- All artifact names below are relative to `/tmp/fenr-modernization/` unless stated otherwise.
- Test counts use xcresult top-level `passedTests`, `failedTests`, and `skippedTests`. Parameterized invocation totals can differ. XCTest bridge messages saying "Executed 0 tests" do not describe the Swift Testing target results.
- Toolchain: Xcode 26.6 release candidate (build 17F109, bundle version 24955), Apple Swift 6.3.3, iOS and watchOS Simulator SDKs 26.5, XcodeGen 2.46.0. Installed runtime coverage includes iOS 26.5 and 17.5, and watchOS 26.5 and 10.5.

## Phase and commit record

| Phase | Commit(s) | Delivered scope | Recorded validation |
| --- | --- | --- | --- |
| 0 | Baseline `7f393cfd` | Baseline before modernization | iOS 1326 passed; Watch 297 passed; zero failures/skips; strict lint clean. `baseline-summary.json`. Initial iOS 17 compatibility run later failed/stalled; it was not a baseline pass. |
| 1 | `e25d2762` | XcodeGen templates/configuration and development documentation | Resolved spec comparison and generation idempotence, full iOS 1326/Watch 297, debug build and lint passed. Local signing values excluded from commits. |
| 2 | `765b9815` | Atomic VIN-scoped semantic settings updates, versioned replay, FIFO optimistic overlays, explicit settings failures, PIN result handling | Full iOS 1359/Watch 314 passed. Tests include no-op revision behavior, corruption preservation, context changes, optimistic failure recovery and confirmed name-save completion. |
| 3 | `8e860693` | Throwing history and maintenance reads; loading/error/empty separation; retry and reminder handling | Full iOS 1385 passed, final debug build/lint passed. `phase3-summary5.json`, `phase3-ios-attempt5.xcresult`. |
| 4a | `daadebe0`, `9c1be150` | Live Activity fixture subscription barriers; Library controller extraction | Focused 212 passed, final debug build/lint passed. Accepted completed route writes survive stop/deinit and serialize across context changes. `phase4a-summary4.json`. |
| 4b | `49d77209` | Planning controller extraction and guarded effects | Focused 223 passed plus final two presentation regressions passed. Search/preview channel isolation and buffered initial-preview acknowledgement covered. `phase4b-final-summary.json`. |
| 4c | `ab3e6e86` | Activity controller extraction; removal of broad State/OperationStore ownership | Focused 231 passed. Pending terminal effects, replay, stale preparation, mini-map snapshots and single location ownership covered. `phase4c-summary.json`. |
| 5a | `b2a650b6`, `68da7cee` | Demo setup fixture ordering; BikeDemo Observation pilot | Four new BikeDemo cases; focused 95 top-level tests passed. Overlapping stop/select cancellation ownership covered. Demo scenario UI inspected. |
| 5b | `277cb512` | Observation in eight independent iPhone features | Focused 265 top-level tests and Watch 314 passed; five new secondary-output/detail tests. Normal/debug builds and lint passed. |
| 6 | `2a456e81` | Four Watch Observation classes and SwiftUI ownership; required debug framework embedding | Watch 317 passed on both 26.5 and 10.5 after embedding correction. Actual Watch riding/settings/charging UI inspected. |
| 7 | `2e15d42e` | Dashboard, BatteryHealth and ChargeControl Observation; synchronous charge stream; explicit card lifecycle | Focused 312 passed; normal/debug/physical builds and lint passed. Replay, ordered nested updates, cancellation/unsubscribe and consumer restart covered. Physical installation and launch succeeded for this phase. |
| 8 | `41862094` | App and Navigation Observation shells; lazy feature ownership | Full iOS 1439 passed. Normal/debug builds and lint passed. Manual demo route record/mini/expand/finish/save inspected. |
| 9 | `d4ed49c6`, `1fb9b6b2` | Fractional ISO-8601 compatibility; bounded trace tests; architecture/runtime validators and CI configuration | iOS 17.5 full 1441 passed; iOS 26.5 BLETraceData 39 passed; Watch 10.5 full 317 passed; real app bundle validators passed. Exact old-runtime preflight booted 17.5 and 10.5 without fallback. |
| 10 | `036f7d5a`, `41f59f82`, `30c8e6cc` | Demo location test isolation and lifecycle readiness; maintenance focus correction; isolated debug harness and seven iPhone E2E scenarios | App/Debug 102 passed; MaintenanceLog 22 passed; final primary E2E 7 passed, 0 failed, 0 skipped on the tree committed as `30c8e6cc`. |
| 11 | `5895cb36` (test-only); QA record | Final regression matrix, keyboard-overlay recovery, compact iPhone E2E, Release rebuilds and visual review | Final iOS 1445 and Watch 317 passed on both runtime pairs; Release and bundle checks passed for production `30c8e6cc`. Fresh SE Maintenance passed with the helper fix. Fresh primary and compact E2E reruns each passed 7/0/0 at `5895cb36`. |

Phase-specific counts above are supported by the progress record and named summaries where available. The following latest matrix was independently read directly from the actual xcresult bundles.

## Latest completed automated matrix

| Check | Runtime/configuration | Actual result | Artifact |
| --- | --- | --- | --- |
| Full FENR tests | iPhone 17, iOS Simulator 26.5 | 1445 passed, 0 failed, 0 skipped | `phase11-ios-full.xcresult`, `.log` |
| Full FENR tests | iOS Simulator 17.5 | 1445 passed, 0 failed, 0 skipped | `phase11-ios17-full.xcresult`, `.log` |
| Full FENRWatchDebug tests | Watch Series 11, watchOS Simulator 26.5 | 317 passed, 0 failed, 0 skipped | `phase11-watch-full.xcresult`, `.log` |
| Full FENRWatchDebug tests | watchOS Simulator 10.5 | 317 passed, 0 failed, 0 skipped | `phase11-watch10-full.xcresult`, `.log` |
| App and Debug focused tests | iOS Simulator 26.5 | 102 passed, 0 failed, 0 skipped | `phase10-unit-attempt6.xcresult` |
| MaintenanceLog after focus fix | iOS Simulator 26.5 | 22 passed, 0 failed, 0 skipped | `phase10-maintenance-unit-fix.xcresult` |
| Fresh SE Maintenance E2E with keyboard recovery | iPhone SE (3rd generation), iOS Simulator 26.5 | 1 passed, 0 failed, 0 skipped; test-only fix `5895cb36` | `phase11-maintenance-fresh-recovery.xcresult`, `.log` |
| Primary complete E2E suite | Fresh iPhone 17, iOS Simulator 26.5 | 7 passed, 0 failed, 0 skipped; exact `5895cb36` source tree | `phase11-e2e-primary-integrated.xcresult`, `.log` |
| Normal/debug iPhone build | iOS Simulator, Debug | TEST BUILD SUCCEEDED, including both app hosts | `phase11-keyboard-recovery-build.log` |
| WatchDebug visual build | watchOS Simulator, Debug | BUILD SUCCEEDED; installed and launched for visual QA | `phase11-watch-visual-build.log` |
| Compact complete E2E suite | Fresh iPhone SE (3rd generation), iOS Simulator 26.5 | 7 passed, 0 failed, 0 skipped; exact `5895cb36` source tree | `phase11-e2e-compact-integrated.xcresult`, `.log` |
| iOS Release build | iOS Simulator, Release | BUILD SUCCEEDED | `phase11-ios-release.log` |
| Watch Release build | watchOS Simulator, Release | BUILD SUCCEEDED | `phase11-watch-release.log` |
| Normal/debug runtime bundle validation | Final iPhone Debug app hosts, production `30c8e6cc` | 46/44 images; no findings | `phase11-integrated-normal-frameworks.json`, `phase11-integrated-debug-frameworks.json` |
| Release runtime bundle validation | Final iOS/Watch apps at `30c8e6cc` | 40/16 images; no findings | `phase11-ios-release-frameworks.json`, `phase11-watch-release-frameworks.json` |
| WatchDebug runtime bundle validation | Final WatchDebug app at `30c8e6cc` | 17 images; no findings | `phase11-watch-debug-frameworks.json` |
| Architecture scan | 92 targets, 1265 production source files | 0 issues; 3 documented exceptions | `phase11-integrated-architecture.json` |
| Strict SwiftLint | 1770 files | 0 violations, 0 serious | `phase11-integrated-lint.log` |
| Architecture Python suite | Local | 9 passed | `phase10-architecture-tests.log` |
| Runtime preflight Python suite | Local | 8 passed | `phase10-compatibility-tests.log` |
| Mach-O runtime framework Python suite | Local | 19 passed | `phase10-framework-tests.log` |
| Existing review-document Python suite | Bundled Python with dependencies | 4 passed | `phase10-review-document-tests-bundled.log` |
| Complete Python discovery | Python environment with required dependencies | 40 passed, 0 failures/errors | `phase10-final-script-tests.log` |

The Phase 11 full suites, Release builds and final Release/WatchDebug bundle checks validate production code `30c8e6cc`, including the BatteryHealth accessibility identifier adjustments and Maintenance focus correction. The final integrated normal/debug app hosts were also validated directly from their built bundles; all 46/44 images passed. Test-only fix `5895cb36` passed a focused fresh-simulator Maintenance run and both complete fresh seven-scenario E2E suites. No tests were skipped in the final matrix.

The initial broad Python discovery command did fail: `phase10-script-tests.log` reports 37 items with one import error because system Python lacked `reportlab`. The three new validator suites subsequently passed separately (36 tests total), all four document tests passed with the bundled Python, and final combined discovery passed all 40 tests in `phase10-final-script-tests.log`. The validator suite intentionally prints a missing-library error for a negative fixture even when the suite result is OK. The failed broad invocation is retained as failed evidence.

## iPhone E2E scope and integrated result

Six scenarios run in the debug-only isolated harness; the seventh enters the normal app through public demo onboarding. Debug sessions use an explicit UUID namespace. Reset targets only that namespace, while relaunch without reset preserves its defaults and actual stores. Persistent read-failure toggles cannot be consumed accidentally by startup/dashboard reads. Deterministic GPS and route-save failure controls are debug-only.

1. Independent settings survive navigation and relaunch.
2. History list and detail recover from controlled read failures.
3. Maintenance retry, create, edit, relaunch and delete preserve exact content.
4. Navigation recording, pause/resume, mini mode, save and relaunch preserve a route; multiple GPS samples make distance checks meaningful.
5. A failed route save preserves the summary and entered name; retry persists exactly one route.
6. Charging power/target confirmation preserves sibling values and agrees with dashboard configuration, using the emulator.
7. Public demo onboarding, scenario selection, Change Bike and relaunch return to onboarding without the debug harness.

The final integrated runs are `phase11-e2e-primary-integrated.xcresult` and `phase11-e2e-compact-integrated.xcresult`, each with 7 passed, 0 failed and 0 skipped at `5895cb36`. Both owned simulators were prepared from an empty state, and the two complete suites ran serially. The debug runner was preinstalled before each suite; normal FENR entered through actual public demo onboarding.

The first compact attempt could not install the CoreSimulator runner: the six debug cases did not run, while public demo passed. Later complete compact attempts passed six scenarios and exposed the first-use keyboard overlay in Maintenance. After the helper correction, focused fresh SE Maintenance and both complete seven-scenario runs passed. The final compact suite exercised the keyboard recovery again and preserved the exact unsaved value. Earlier failed or interrupted attempts are not counted as successful validation.

## Failures investigated and corrected

- Initial iOS 17 trace decoding rejected fractional timestamps. A waiting test then waited indefinitely for a non-empty snapshot. The decoder now handles fractional/non-fractional ISO-8601 explicitly; the test observes a bounded initial result and can fail on an empty result. Final old-runtime suites passed.
- Real WatchDebug launch exposed a missing transitive BLETraceDomain framework. Embedding was corrected, and actual-built-bundle validation now covers load commands, architecture selection, inherited load paths and cyclic dependencies.
- Settings migration tests exposed replay ordering, idempotent hidden-page updates, corrupt persisted types/legacy records, stale preview preferences and name-editor completion issues. These were corrected with focused regression coverage before Phase 2 completion.
- History teardown briefly cancelled a still-presented detail. The list-only stop contract was restored and the existing lifecycle test retained. Confirmed maintenance saves/deletes now keep required reminder cleanup/authorization behavior across read failures and view lifecycle changes.
- Navigation extraction reviews found accepted writes dropped across a context reset, search/preview loading and buffered-effect conflicts, and terminal-effect replay hazards. Controller changes and focused tests cover these cases.
- Live Activity/lifecycle test fixtures used scheduling delays or observed intermediate stop states. Explicit subscriber/readiness and complete rollback barriers replaced these assumptions.
- Demo storage test diagnostics confirmed that persisted metric settings remained intact while the model sometimes received no snapshot. Platform speed construction was moved into explicit production composition and the fixture now supplies a no-op speed repository. This removes a hidden platform dependency from storage tests; it is not proof that Core Location was the precise cause of the earlier scheduling failure. All temporary diagnostic prints were removed.
- E2E attempts found inaccessible container identifiers, localized numeric formatting, native text selection problems and a real Maintenance focus reset. Identifiers now target actual accessibility elements, assertions compare appropriate values, native selection waits for exact replacement, and the competing form tap behavior was removed in `41f59f82`. The maintenance scenario passed after that fix.
- Fresh compact simulator attempts exposed a first-use bilingual keyboard introduction covering the form toolbar. A scoped Continue handler did not dismiss it: both XCTest and a manual simulator tap instead inserted a space into the underlying field. Test-only fix `5895cb36` recognizes that exact introduction, sends the app to the background with Home, reactivates the same app, and requires the introduction to disappear. The fresh SE regression exercised this branch and verified that the exact unsaved workshop value survived before completing create/edit/relaunch/delete. That test case passed in approximately 174.8 seconds (`phase11-maintenance-fresh-recovery.xcresult`). The unsuccessful Continue handler was removed; no production workaround was added. Six other scenarios passed in the earlier complete failed compact runs.
- Temporary compiler/integration errors and a zero-matching diagnostic test invocation were corrected or discarded. Zero executed tests and interrupted runs are not counted as validation.

## Phase 11 final checks

| Final check | Status | Evidence |
| --- | --- | --- |
| Full iOS regression on final code | Passed: 1445/0/0 on 26.5 and 17.5; `30c8e6cc` | `phase11-ios-full.xcresult`, `phase11-ios17-full.xcresult` |
| Full Watch regression on final code | Passed: 317/0/0 on 26.5 and 10.5; `30c8e6cc` | `phase11-watch-full.xcresult`, `phase11-watch10-full.xcresult` |
| Fresh primary E2E with final test helper | Passed: 7/0/0 | `phase11-e2e-primary-integrated.xcresult` / `.log`; production `30c8e6cc`, tests `5895cb36` |
| Complete fresh compact iPhone E2E with final test helper | Passed: 7/0/0 | `phase11-e2e-compact-integrated.xcresult` / `.log`; production `30c8e6cc`, tests `5895cb36` |
| Final iOS Release rebuild and runtime bundle validation | Passed; 40 images, no findings; `30c8e6cc` | `phase11-ios-release.log`, `phase11-ios-release-frameworks.json` |
| Final Watch Release rebuild and runtime bundle validation | Passed; 16 images, no findings; `30c8e6cc` | `phase11-watch-release.log`, `phase11-watch-release-frameworks.json` |
| Final visual review | Passed for inspected iPhone and Watch screens | Primary landscape charging/riding; portrait settings/history/maintenance; Watch riding/charging/settings; compact navigation/charging/settings/demo and fresh Maintenance edit; primary Bike Lock, Diagnostics, bike information and Battery Health overview |

## Visual inspection

On the final production code, native Simulator inspection confirmed readable primary iPhone landscape riding and charging dashboards, and Watch Series 11 riding, charging and settings screens. Primary portrait E2E captures were inspected for Ride Display settings, history read failure/retry, persisted maintenance details and confirmed charging controls. No overlapping controls or truncated required content were observed in these views. Captures are stored outside Git as `phase11-primary-charging-landscape.png`, `phase11-watch-riding.png`, `phase11-watch-charging.png`, `phase11-watch-settings.png` and `phase11-primary-captures/`.

Earlier landscape app-bounds screenshots were cropped during forced orientation despite a correct native Simulator display. Both E2E capture helpers now use the full screen screenshot API. Full-screen compact captures now show the complete landscape recording summary, mini navigation and public demo dashboard, plus portrait charging/settings screens. These inspected views were readable. The failed-save summary intentionally scrolls vertically on the compact screen. The final fresh SE Maintenance edit capture in `phase11-maintenance-fresh-captures/` shows the full workshop value "FENR QA Workshop" and notes "Chain inspected and adjusted", with readable Edit/Delete controls and no overlap or truncation. Final primary integrated captures in `phase11-primary-integrated-captures/` were reviewed for public demo, mini navigation, save recovery, maintenance, history error/retry and confirmed charging. They show complete, readable content. Final compact integrated maintenance, completion and retry captures were also reviewed in `phase11-compact-integrated-captures/`, with readable content and normal scrolling on the smaller screen.


Final native primary iPhone spot-checks also covered Bike Lock overview, Diagnostics live summary, Diagnostics > Connection (bike information), and Battery Health overview. These used the debug charging scenario without UI-test controls. Required content was readable, including wrapped synthetic identity information; no PIN or vehicle-write actions were performed. Captures are `phase11-primary-bikelock.png`, `phase11-primary-diagnostics.png`, `phase11-primary-bike-information.png` and `phase11-primary-batteryhealth.png`.

Independent subagents reviewed each implementation phase and the final automated matrix against its actual result bundles. The final keyboard recovery and capture changes were independently reviewed before integration. No known modernization regression remains unresolved. Owned Swift sources were scanned again and contain no `ObservableObject`, `@Published`, `@ObservedObject`, `@StateObject` or `@EnvironmentObject` uses.

## Coverage limits

- Final iOS/Watch Release rebuilding and bundle validation passed for production code `30c8e6cc`. This is simulator build evidence, not an archive, App Store upload or distribution validation.
- CI configuration and its scripts were locally reviewed/tested. No remote GitHub Actions execution or passing CI run is evidenced here.
- Watch has automated unit coverage and manual simulator UI checks. Automated XCUITest E2E coverage is iPhone only.
- Scene factory ownership was reviewed and exercised through UI navigation, but no dedicated automated SwiftUI rerender/factory-invocation-count test is recorded.
- The final production signed physical build succeeded (`physical-phase11-build.log`), but installation failed with CoreDevice error 1011 because the paired device/tunnel was unavailable (`physical-phase11-install.json`). The current production tree is not installed. The confirmed physical install and launch remains Phase 7 (`2e15d42e`).
- Physical installation is not motorcycle write validation. Charging E2E uses the emulator. This work supplies no new physical VCU, traction-control or bike-lock write evidence and does not expand their authorization/capability gates.
- Captures and result bundles remain under `/tmp/fenr-modernization/`, outside Git. Local signing data, simulator IDs, physical device identifiers and raw captures are intentionally omitted from this report.
