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
| `AsyncSupport` | Cross-app asynchronous support utilities used by tests and infrastructure. |

## Session ownership

`AppRootView` owns the iPhone `BikeSessionController`. It starts and stops the repository once for the application lifecycle. Feature modules observe streams through use cases, so moving from the dashboard to settings or diagnostics does not create a second Bluetooth session.

`WatchRootView` owns an independent `WatchBikeSessionController`. It connects directly through the Watch's Bluetooth stack, without requiring the paired iPhone at runtime, and declares the Bluetooth central background mode. watchOS still controls suspension and screen wake behaviour, so background support preserves the session when execution is available rather than guaranteeing continuous execution. Battery-health monitoring starts only while the bike reports charging.

## Main features

- `BikeOnboarding`: discovers/selects a motorcycle, validates its identity, and completes setup only after telemetry is received.
- `RideDashboard`: presents live riding and charging states. It displays confirmed telemetry only.
- `BikeDiagnostics`: exposes advanced connection status and raw diagnostic context as a secondary destination.
- `BatteryHealth`: presents battery and cell measurements and owns the guarded iPhone UI flow for charging-power and charge-target writes.
- `AppSettings`: stores speed-source, measurement-system, and battery-capacity preferences.
- `PowerModeSettings`: presents confirmed map values and owns the guarded flow for base-map horsepower, regenerative braking, TC, and TC Regen changes.
- `WatchDashboard`: presents a native, compact Watch ride/charge surface with battery, gear/map, odometer, charging power/current, pack temperature, and charge ETA when available.

## Dependency direction

Dependencies point inward: features consume domain contracts and use cases; data implements those contracts; SDK and protocol code stay below product/UI layers. `DesignSystem` is a feature dependency only and must not leak into domain, data, SDK, or protocol modules.

## Vehicle writes

Vehicle writes are explicit use cases rather than generic BLE access. Battery Health requests a charge-control preparation through the domain repository; `BikeData` maps it to `BikeSDK`, and the SDK serializes writes to the VCU charger configuration characteristic. `StarkProtocol` owns the immutable configuration payload and encoder.

The charge-control flow requires compatible VCU PIC firmware, an authenticated session, a connected charger, the required characteristic, and a successful unchanged no-op write. Power and target changes preserve every unrelated field and are accepted only after the charger telemetry reports the requested value. A timeout desynchronizes the transport until the BLE session reconnects, preventing a late response from confirming a newer operation.

Power Mode Settings reads base-map type `0` and traction-control type `8` for all five maps. Type `0` accepts curve selector `0` or `mapIndex + 1`, rejects other selectors, and normalizes every write to `mapIndex + 1`. Type `8` is independently gated at VCU PIC firmware 1.10.1 and writes TC and TC Regen as whole percentages from 0 through 100, encoded as signed 16-bit tenths with mode `0x0F`. Each record has a separate preparation state, exact no-op, sibling-value preservation, successful write-status requirement, and fresh matching response, so unavailable TC does not disable horsepower and regen. The shared serialized `4005` transport prevents competing operations, and acknowledgement alone is never success. Base-map writes have physical write/read-back evidence; TC writes still require equivalent physical validation.
