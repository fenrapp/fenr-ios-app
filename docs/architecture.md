# Architecture

## Overview

FENR is structured as a modular Swift application. The goal is to keep vehicle telemetry, product behaviour, and SwiftUI presentation independently testable.

## Layers

| Layer | Responsibility |
| --- | --- |
| `App` | App composition, top-level navigation, dependency wiring, and the single BLE session lifecycle. |
| `Features` | SwiftUI screens, view models, presentation mappers, and feature-specific containers. |
| `*Domain` | Entities, repository protocols, and use cases. |
| `*Data` | Repository implementations, persistence, and mappings from lower layers. |
| `BikeSDK` | Platform Bluetooth integration and authenticated telemetry transport. |
| `StarkProtocol` | Clean-room UUID catalogues, payload parsing, and pairing identity helpers. |
| `DesignSystem` | SwiftUI-only shared colours, spacing, radii, and reusable visual components. |
| `AsyncSupport` | Cross-app asynchronous support utilities used by tests and infrastructure. |

## Session ownership

`AppRootView` owns `BikeSessionController`. It starts and stops the repository once for the application lifecycle. Feature modules observe streams through use cases, so moving from the dashboard to settings or diagnostics does not create a second Bluetooth session.

## Main features

- `BikeOnboarding`: discovers/selects a motorcycle, validates its identity, and completes setup only after telemetry is received.
- `RideDashboard`: presents live riding and charging states. It displays confirmed telemetry only.
- `BikeDiagnostics`: exposes advanced connection status and raw diagnostic context as a secondary destination.
- `BatteryHealth`: presents battery and cell measurements.
- `AppSettings`: stores speed-source, measurement-system, and battery-capacity preferences.

## Dependency direction

Dependencies point inward: features consume domain contracts and use cases; data implements those contracts; SDK and protocol code stay below product/UI layers. `DesignSystem` is a feature dependency only and must not leak into domain, data, SDK, or protocol modules.
