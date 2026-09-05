# FENR - Reviewer Guide

Thank you for reviewing FENR - Unleash your varg. FENR is an independent,
open-source iPhone app for Stark Varg riders, providing a riding dashboard,
charging information, battery diagnostics, ride history and maintenance records.

Please use **Explore demo > Start demo** to review the app. No motorcycle,
account or sign-in is required. The demo is built into the submitted application
and gives access to the main screens and interactions.

## Access

1. Launch FENR and select **Explore demo** on the welcome screen.
2. On the introduction screen, select **Start demo**.
3. The dashboard opens with a **Demo** control. Tap it to switch between
   **Parked**, **Riding**, **Charging** and **Battery issue**.

To open Settings, swipe up through the dashboard's central cards and tap
**Open Settings**. On the Charging dashboard, use the **Settings** button.
The demo controls are also available in Settings.

## Suggested review

- **Riding:** select Riding in the Demo control. The dashboard displays sample
  speed, battery, power and riding-mode information. Explore the dashboard cards
  and their expanded views.
- **Charging:** select Charging. The dashboard displays sample charging progress,
  power and remaining time. Adjust the charging-power and battery-target controls
  to see their behavior in the demo.
- **Battery issue:** select Battery issue, then open Settings > Diagnostics >
  Battery Health. The battery screen shows a sample cell anomaly and detailed
  battery readings.
- **Parked:** select Parked. Open Settings to explore dashboard customization,
  measurement units and power-mode settings. Bike Lock can be explored using
  the authentication options available on the review device.
- **Ride History and Maintenance:** open these screens from Settings. The demo
  starts with three sample rides and two maintenance entries. Open a record and
  try the available editing actions.
- **Persistence:** close and reopen FENR. The demo motorcycle, selected scenario
  and saved changes remain available. Deleted sample records are not recreated
  when the app is relaunched.

## Demo behavior

Motorcycle readings and responses to motorcycle controls are simulated in demo
mode. The demo does not connect to or make changes to a real motorcycle.

Navigation and the compass use the iPhone's actual location or sensors when
available. Place searches and road directions use Apple Maps and may require
Internet access. The demo does not simulate GPS travel. You can review the
motorcycle dashboard and battery features without enabling location access.

## Permissions and external services

- **Bluetooth:** used when an owner connects a real motorcycle. It is not needed
  for the demo walkthrough.
- **Location:** used for GPS speed, ride recording and navigation when permitted.
  Declining location access does not prevent using the motorcycle demo.
- **Local authentication:** used by Bike Lock. Follow the options shown on the
  device; cancelling authentication returns to the app without completing the
  protected action.

## Exit

Open Settings and select **Change Bike** to return to the welcome screen.
Select **Explore demo > Start demo** again to resume the saved demo experience.
The demo's saved preferences and records remain separate from real motorcycle data.

## About the motorcycle connection

For owners, FENR connects directly to a compatible Stark Varg over Bluetooth.
The owner selects their motorcycle and completes the pairing flow on the iPhone.
Available readings and controls depend on the motorcycle's firmware.
The built-in demo provides the review experience described above without this
connection or any additional hardware.

FENR is an independent project and is not affiliated with or endorsed by Stark
Future.

## Support and policies

Settings includes **Help & Support**, **Privacy Policy** and **Terms of Use**.
These open the following pages in the system browser:

- [Support](https://fenr.to)
- [Privacy Policy](https://fenr.to/privacy)
- [Terms of Use](https://fenr.to/terms)

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
