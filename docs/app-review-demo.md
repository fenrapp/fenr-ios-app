# App Review: iPhone demo mode

FENR works with compatible electric motorcycles. Reviewers can explore the iPhone
app without a motorcycle, account, Bluetooth connection, or location permission.

## Access

1. Launch FENR and tap **Explore demo** on the welcome screen.
2. Read the introduction and tap **Start demo**.
3. Tap the **Demo** button to choose **Parked**, **Riding**, **Charging**, or
   **Battery issue**. The same controls are available in Settings.

The demo creates a synthetic motorcycle identity. Its scenario, confirmed bike
settings, map names, ride history, and maintenance records survive app relaunches.
All app preferences are stored per VIN, including dashboard layout, units and
navigation appearance. Existing preferences migrate to the selected VIN; a new
motorcycle starts with defaults. The simulation state also records its VIN.
The initial data includes three sample rides and two sample maintenance entries.
Deleting a sample does not recreate it on the next launch.

## Suggested review

- **Parked:** explore the dashboard, customize cards, edit power modes, and try
  Bike Lock using the normal local authentication options.
- **Riding:** observe simulated speed, power, odometer, and ride statistics.
- **Charging:** adjust maximum charging power and the battery charge limit.
- **Battery issue:** open Settings, Diagnostics, then Battery Health to inspect
  the simulated cell anomaly.
- Open Ride History and Maintenance from Settings to inspect or edit the sample
  records. Live Activities and supported exports identify the demo context.
- Close and relaunch the app to verify that the same demo bike and settings return.

The dashboard compass uses the iPhone magnetometer while stationary and a reliable
GPS course when moving. Compass readings are real, including during the demo;
opening the compass does not require a simulated route.

Navigation uses the iPhone's actual location if permission is granted. Map content
and place searches may require Internet. The demo does not simulate GPS travel.
Denial of location permission does not prevent reviewing the motorcycle features.

Settings > **Help & Support** opens https://fenr.to in the system browser in both
the real and demo experiences. Returning to FENR retains the Settings screen.
Settings > **Legal** links to Privacy Policy and Terms of Use. Settings >
**Acknowledgments** lists the community projects and development tools that
helped make FENR possible, with links to their public repositories.

The iPhone app accepts Apple Maps direction requests, shared map links, and GPX
routes. Road directions require Internet and depend on Apple Maps availability;
worldwide geographic coverage does not guarantee a road route for every location
or offline maps. The iOS submission coverage file and remaining publication
checks are described in [the App Store checklist](app-store/README.md).

## Exit

Open Settings and choose **Change bike**. This ends the demo and cancels its active
Live Activities and reminders. The demo identity, isolated data, settings, and
credentials stay saved. Choose **Explore demo** again to resume the same demo bike,
including changes to or deletions of sample records. Real motorcycle data remains
separate. Leaving the demo does not automatically select it on the next launch.

## Review boundaries

The demo is available to all users in the production iPhone app. It does not
contact, authenticate with, or write to a physical motorcycle. Diagnostic values
and write confirmations in demo mode are simulated; they do not establish physical
validation of traction-control or bike-lock writes. Raw BLE capture requires real
hardware and is unavailable in the demo.

The Apple Watch app continues to connect directly to a motorcycle and does not
include this demo. Provide a separate video showing the real hardware and Watch
flows if requested by App Review. The demo does not guarantee approval.

Apple guidance: https://developer.apple.com/app-store/review/

## Engineering validation

Validated with Xcode 26.6 and iPhone 17 on iOS 26.5:

- 1,245 tests passed in the FENR scheme; strict SwiftLint passed.
- 74 app tests passed after adding demo isolation and VIN migration coverage for preferences, profile,
  trips, maintenance, calibration, routes, incoming map links, credential service
  selection, and shutdown ordering before constructing real feature models.
- Recovery tests cover damaged demo selections, retaining saved data while returning to setup.
- 288 Watch tests passed with VIN-scoped settings enabled.
- FENRDebug and unsigned Release builds of FENR and FENRWatch passed.
- The signed simulator app was used for Keychain-dependent runtime checks.
- Manual checks covered welcome and Bluetooth-unavailable entry, all four
  scenarios, sample history and maintenance, power-map edits, relaunch persistence,
  and Change Bike returning to setup while retaining the demo for re-entry.
- Portrait and landscape layouts, enlarged Dynamic Type, Reduce Motion, and
  accessibility names/selection traits were inspected.

Spoken VoiceOver, physical Bluetooth reconnection, and real GPS movement remain
checks for a physical iPhone. Simulator results do not validate vehicle writes.
