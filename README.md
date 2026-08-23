# FENR iOS ⚡️🏍️

FENR is an independent iOS dashboard and read-only diagnostics app for compatible electric motorcycles. It turns live Bluetooth telemetry into a clear riding display, battery insight, and practical diagnostics without pretending to be the one true client for a machine you own.

> **Unofficial and independent.** FENR is not affiliated with, endorsed by, sponsored by, or otherwise connected to Stark Future or any vehicle manufacturer. Names used in technical compatibility code remain the property of their respective owners.

## What is here? ✨

- A live landscape ride dashboard with battery, speed, gear/map, indicators, charging state, and an adaptive compact presentation.
- Battery health and cell-voltage views.
- Read-only diagnostics, connection logging, and a developer emulator.
- First-run bike onboarding and Bluetooth pairing flow.
- Optional device GPS speed, plus metric, imperial, and system unit preferences.
- A focused SwiftUI design system shared by the app features.

FENR is intentionally **read-only**. It does not bypass safety controls, change vehicle behaviour, or send undocumented control/configuration commands. Authentication required by the existing telemetry connection is the only write-related protocol activity in this app.

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

The app keeps SwiftUI features separate from domain contracts, data implementations, SDK/BLE code, and protocol decoding. `App` owns app-level composition and the single BLE session; features consume explicit use cases rather than opening competing connections.

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
