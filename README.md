# FENR ⚡️🏍️⌚️

FENR is an independent iPhone and Apple Watch dashboard, diagnostics, and charging-control app for compatible electric motorcycles. It turns live Bluetooth telemetry into a clear riding display, battery insight, practical diagnostics, and a small set of guarded VCU charging controls without pretending to be the one true client for a machine you own.

> **Unofficial and independent.** FENR is not affiliated with, endorsed by, sponsored by, or otherwise connected to Stark Future or any vehicle manufacturer. Names used in technical compatibility code remain the property of their respective owners.

## What is here? ✨

- A live landscape ride dashboard with battery, speed, gear/map, indicators, charging state, and an adaptive compact presentation.
- Battery health and cell-voltage views, including copyable charging telemetry for hardware diagnostics.
- Authenticated charge-power and charge-target controls from the charging dashboard and Battery Health on supported VCU firmware.
- Guarded base-map horsepower, regenerative-braking, TC, and TC Regen controls.
- Read-only diagnostics, connection logging, and a developer emulator.
- First-run bike onboarding and Bluetooth pairing flow.
- Optional device GPS speed, plus metric, imperial, and system unit preferences.
- A focused SwiftUI design system shared by the app features.
- A standalone Watch app that connects directly to the motorcycle for compact ride and charging telemetry, with Bluetooth background support subject to watchOS execution limits.

Most of FENR remains read-only. Its write surface is deliberately limited to maximum charging power, target state of charge, and guarded base riding-map horsepower, regenerative braking, traction control, and regen traction control. FENR does not write custom curves, bypass safety controls, modify firmware, or expose arbitrary configuration writes.

## Charging controls

The iPhone charging dashboard and Battery Health screen share one guarded control session that can adjust two values over the existing authenticated Bluetooth connection:

- Maximum charging power in 100 W steps. FENR currently exposes 300-3,300 W for standard, backpack, and unknown chargers, and 300-7,000 W for fast chargers.
- Charge target from 1% through 100% in 1% steps.

These controls are enabled only for VCU PIC firmware 1.9.1 or newer and while a charger is connected. Before enabling them, FENR reconstructs or reads the current charger configuration and sends an unchanged no-op command. Every later command preserves the other configuration fields, is serialized, and must be confirmed by charger telemetry.

Each slider keeps its draft value inside the SwiftUI view while it is being dragged, so incoming telemetry cannot move the control. SwiftUI submits only the released value; the application applies it optimistically and sends it after a one-second debounce. Pending operations are cancelled or queued as appropriate, and timeouts or telemetry mismatches leave a copyable diagnostic entry instead of silently accepting the requested value.

The Apple Watch app remains telemetry-only. Charging configuration is available from the iPhone charging dashboard and Battery Health screen.

## Power-mode controls

FENR can edit horsepower, regenerative braking, TC, and TC Regen for the five base maps. The base flow accepts only the observed zero curve selector or that map's standard selector and normalizes every outgoing selector to `mapIndex + 1`, matching the official client's behavior. Physical captures now confirm that base-map writes persist across fresh reads. TC uses the separate type `8` record on VCU PIC firmware 1.10.1 or newer. It sends whole percentages from 0 through 100 as signed 16-bit tenths, uses write mode `0x0F`, and requires a successful VCU write status plus an exact fresh read. Base and TC controls each require their own no-op and preserve the sibling value. TC writes still need physical write/read-back validation, and custom-curve writes remain out of scope.

## Why FENR? 🛠️

Owning a machine should include being able to understand it and choose the client that works best for you. Good public APIs make that possible: they let riders use accessible dashboards, build better tooling, and keep their data experience from being tied to a single vendor app.

This project supports responsible interoperability, not shortcuts around safety. We think vehicle manufacturers should offer stable public APIs and give owners a real choice of clients, while preserving the boundaries that keep a motorcycle safe to operate.

## Protocol research 🔬

The clean-room protocol work lives separately in [FENR Bike Protocol Research](https://github.com/fenrapp/bike-protocol-research). This repository contains the iOS application, not raw captures, APK material, credentials, or private research notes.

## Getting started 🚀

Requirements:

- A recent Xcode release with an iOS 16+ simulator/runtime.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen).
- [SwiftLint](https://github.com/realm/SwiftLint).

```sh
brew install xcodegen swiftlint
xcodegen generate
open FENR.xcodeproj
```

Use the `FENRDebug` scheme to exercise the emulator without a motorcycle. More detail is available in [docs/development.md](docs/development.md).

## Architecture 🧭

The app keeps SwiftUI features separate from domain contracts, data implementations, SDK/BLE code, and protocol decoding. `App` owns the iPhone BLE session, while `Watch` owns a separate direct Watch session; features consume explicit use cases rather than opening competing connections.

Read [docs/architecture.md](docs/architecture.md) for the module map and [docs/testing.md](docs/testing.md) for test conventions.

## Quality checks ✅

```sh
xcodegen generate
swiftlint lint --strict
FENR_SIMULATOR='<an installed iOS Simulator name>'
xcodebuild -project FENR.xcodeproj -scheme FENR \
  -destination "platform=iOS Simulator,name=$FENR_SIMULATOR" test
xcodebuild -project FENR.xcodeproj -scheme FENRDebug \
  -destination "platform=iOS Simulator,name=$FENR_SIMULATOR" build
```

## Contributing 🤝

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), follow the [Code of Conduct](CODE_OF_CONDUCT.md), and report security concerns through [SECURITY.md](SECURITY.md).

## License

FENR is released under the [MIT License](LICENSE).
