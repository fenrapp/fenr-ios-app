# Architecture

## Overview

FENR is structured as a modular Swift application. The goal is to keep vehicle telemetry, product behaviour, and SwiftUI presentation independently testable.

## Layers

| Layer | Responsibility |
| --- | --- |
| `App` | iPhone app composition, top-level navigation, dependency wiring, and the single BLE session lifecycle. |
| `Watch` | Standalone watchOS composition, direct Watch Bluetooth lifecycle, and compact onboarding. |
| `Features` | SwiftUI screens, view models, presentation mappers, and feature-specific containers. |
| `*Domain` | Entities, repository protocols, and use cases. |
| `*Data` | Repository implementations, persistence, and mappings from lower layers. |
| `BikeSDK` | Platform Bluetooth integration, authenticated telemetry, and guarded VCU configuration transport. |
| `StarkProtocol` | Clean-room UUID catalogues, payload parsing/encoding, firmware gates, and pairing identity helpers. |
| `DesignSystem` | SwiftUI-only shared colours, spacing, radii, and reusable visual components. |
| `AsyncSupport` | Production asynchronous event-stream support. |
| `TestSupport` | Bounded asynchronous polling and event hubs for test targets. |

## Session ownership

`AppLifecycleController` owns the iPhone `BikeSessionController` and coordinates startup, shutdown, ride services and Live Activities. `AppRootView` receives that lifecycle controller through `AppRootDependencies`. Feature modules observe streams through use cases, so moving from the dashboard to settings or diagnostics does not create a second Bluetooth session.

`WatchSetupController` owns an independent `WatchBikeSessionController` and is supplied to `WatchRootView` through its dependencies. It connects directly through the Watch's Bluetooth stack, without requiring the paired iPhone at runtime, and declares the Bluetooth central background mode. watchOS still controls suspension and screen wake behaviour, so background support preserves the session when execution is available rather than guaranteeing continuous execution. Battery-health monitoring starts only while the bike reports charging.

## Main features

- `BikeOnboarding` and `BikeDemo`: real-bike setup and an isolated, persistent public demo.
- `RideDashboard` and `DashboardCardSettings`: live ride/charge presentation and card customization.
- `BikeDiagnostics` and `BatteryHealth`: opt-in technical capture, saved logs, battery and cell measurements.
- `PowerModeSettings` and `BikeLockSettings`: guarded settings for supported vehicle controls.
- `AppSettings`: preferences and navigation to settings, history, maintenance and diagnostics.
- `RideNavigation`: Apple Maps directions, imported GPX trails, recording and incoming shared destinations.
- `RideHistory` and `MaintenanceLog`: locally stored rides and maintenance records.
- `WatchOnboarding` and `WatchDashboard`: direct-bike setup and a telemetry-only Watch dashboard.

`ChargeControl` coordinates charging settings, `VehicleSession` combines vehicle
and device measurements for iPhone features, and `RideSession` coordinates trip
recording. Their composition reuses the same bike repository.
`ShareExtension` accepts destinations; `LiveActivityExtension` presents charging
updates without owning a Bluetooth connection.

## Supporting modules

| Modules | Responsibility |
| --- | --- |
| `BikeDomain`, `BikeData` | Vehicle contracts, use cases and the shared repository backed by `BikeSDK`. |
| `BikeEmulator` | Simulated vehicle scenarios used by development apps and the public demo. |
| `BLETraceDomain`, `BLETraceData` | Diagnostic capture contracts, log storage and export. |
| `EnvironmentDomain`, `EnvironmentData` | Device location, heading and motion contracts and platform services. |
| `RideSessionDomain`, `RideSessionData` | Trip models, recording contracts and persistent ride history. |
| `RideNavigationDomain`, `RideNavigationData` | Route and destination contracts, GPX handling and saved navigation state. |
| `RideNavigationAppleMaps` | MapKit rendering, place search, road directions and supported map-link resolution. |
| `MaintenanceDomain`, `MaintenanceData` | Maintenance records, reminders and persistence. |
| `SettingsDomain`, `SettingsData` | Preferences, bike setup and dashboard configuration. |
| `MeasurementPresentation` | Shared measurement conversion and localized numeric formatting. |
| `RuntimeConfiguration` | Shared timing and runtime constants for apps, SDK and emulator. |

## Dependency direction

Dependencies point inward: features consume domain contracts and use cases; data implements those contracts; SDK and protocol code stay below product/UI layers. `DesignSystem` is a feature dependency only and must not leak into domain, data, SDK, or protocol modules.

Views under a feature's `UI/` render immutable feature-owned presentation models
and emit semantic intents. Injected mappers convert domain output before a view
model publishes it; views do not consume repository, SDK or domain entities.
Composition roots construct collaborators explicitly. Controllers own and cancel
their asynchronous tasks across stop, reset and reconnection boundaries.

## Vehicle writes

Vehicle writes are explicit use cases rather than generic BLE access. Features
request them through domain contracts; `BikeData` maps to `BikeSDK`, whose shared
VCU transport serializes individual requests inside a shared sequence gate that
also covers complete multi-record read/no-op/write/confirmation operations. `StarkProtocol` owns payloads and encoders.

Each supported record has firmware/capability gates, preparation, a safe no-op,
sibling-value preservation and fresh confirmation. Charging power and target
changes are confirmed by charger telemetry. Base-map, advanced-curve, traction and lock changes
require matching configuration reads. A transport timeout invalidates the
transaction stream until reconnection so a late reply cannot confirm a new write.

Charging controls and base-map changes have physical evidence. Instrumented
advanced-curve, traction-control and lock write/read-back evidence remains incomplete. Protocol
research details and physical validation evidence belong in the
[protocol research repository](https://github.com/fenrapp/bike-protocol-research);
implementation constraints remain in [AGENTS.md](../AGENTS.md).

`PowerModeSettings` composes separate basic and advanced view models, use-case
bundles and presentation mappers through `PowerModeFeatureFactory`. Injected
collaborators own basic controls, advanced operations, names and local presets.
Both destinations share one session observer, a serialized operation controller
and a per-map draft store with separate confirmed configurations. Opening a destination or managing a local
preset never writes to the bike. Apply checks the complete baseline, prepares
all touched records and confirms the complete result before accepting the draft.
A partial failure stops the sequence, attempts a fresh read and never retries a
changed write automatically. A timeout requires reconnection before recovery.

Curve conversions use an injected, versioned calibration profile. Presets are
stored per normalized motorcycle identity and include firmware, power tier and
calibration compatibility. A corrupt preset library cannot be overwritten by an
empty in-memory library. The advanced screen retains Apply, Discard and Save
Preset independently of the basic sliders.

## Startup and diagnostic capture

Production composition opens ride, maintenance and motion-calibration stores before constructing Bluetooth, location or session services. Store errors propagate to the experience controller, which presents a distinct recoverable storage error and serializes Retry. Recovery never deletes saved stores or silently substitutes temporary storage. Demo preparation errors remain separate.

Manual diagnostic capture has its own shared state, independent of the BLE connection. It starts only from Diagnostics, may begin while disconnected with a configured motorcycle, and stays active across reconnection to that same motorcycle. Stop, changing motorcycle or experience, and process relaunch end capture. Capture-disabled paths avoid technical event formatting and buffering while retaining functional telemetry and vehicle-write confirmation. Log history/capture requests prepare log storage lazily instead of gating app startup.
