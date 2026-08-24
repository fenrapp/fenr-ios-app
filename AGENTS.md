# FENR Agent Guide

## Scope

FENR is a read-only iPhone and Apple Watch dashboard and diagnostics app for compatible electric motorcycles. Keep work within that scope. Do not add BLE commands that modify vehicle configuration, behaviour, safety controls, or firmware. Do not add raw captures, credentials, APKs, copied vendor assets, private endpoints, or research notes to this repository.

## Architecture

- `App/` owns application composition, navigation, and the single `BikeSessionController` lifecycle.
- `Watch/` owns the standalone watchOS app shell, direct Watch Bluetooth lifecycle, and compact onboarding.
- `Features/` contains SwiftUI presentation modules. Features may depend on `DesignSystem`, domain modules, and their own use-case/container layer.
- `Modules/*Domain` exposes entities, repository contracts, and use cases.
- `Modules/*Data` implements repositories and persistence.
- `Modules/BikeSDK` owns Bluetooth/platform integration.
- `Modules/StarkProtocol` contains clean-room protocol parsing and pairing utilities. Keep protocol discoveries in the linked research repository, not here.
- `Modules/DesignSystem` is SwiftUI-only. Do not make domain/data/SDK/protocol modules depend on it.
- `Modules/AsyncSupport` contains cross-app asynchronous test/support primitives.

View models depend on use cases and mappers, not concrete data repositories or BLE clients. UI layout constants belong in the owning feature when they are screen-specific; shared visual tokens belong in `DesignSystem`.

## UI Feature Rules

- Structure new UI like the existing feature modules: put screens in `UI/`, reusable view pieces in `UI/Components/`, layout helpers in `UI/Layout/`, UI state helpers in `UI/State/`, previews in `UI/Previews/`, and formatting/text/presentation helpers in `UI/Support` or the existing local folder that matches the feature.
- Before creating a new UI component, design token, formatter, color, spacing scale, radius, font wrapper, or presentation helper, search the feature and `Modules/DesignSystem` for an existing equivalent and reuse it when it fits.
- Use `DesignSystem` for shared SwiftUI colors, spacing, radii, surfaces, and common reusable components. Only create feature-specific constants for values that are genuinely local to that feature or component.
- Split non-trivial SwiftUI views into focused components. Do not collect unrelated UI pieces in broad files such as `Components.swift`, `Views.swift`, or `Style.swift`.
- Keep feature-specific layout/style/text constants in a named constants type owned by the component or feature. Do not leave magic numbers inline in view bodies or modifiers.

## Coding Rules

- Follow existing module boundaries and local patterns before adding abstractions.
- Keep UI text in English.
- Use `StarkPairingIdentity` as the only VIN normalization/validation utility.
- Treat user-provided VINs and real motorcycle identifiers as sensitive data. Never copy them into source, tests, previews, docs, commit messages, logs, or final responses; use synthetic VINs such as `FENRTEST000000001` or shared debug constants instead.
- Preserve the app-wide single BLE session. Navigating between dashboard, settings, diagnostics, and battery health must not create competing telemetry connections.
- The Watch app has its own direct Bluetooth session and must remain foreground-only until an explicit background strategy is designed and validated. Do not route its runtime dependency through a paired iPhone.
- Add only confirmed telemetry to rider-facing UI. Clearly keep experimental protocol candidates out of production presentation.
- Keep all source and docs ASCII unless a user-facing file intentionally uses Unicode, such as README emoji.

## Tests

- Put fakes, mocks, spies, stubs, no-ops, recorders, and test event hubs in the owning target's `Tests/TestDoubles/` directory.
- Put factories assembling production objects in `Tests/Support/` and immutable input data in `Tests/Fixtures/`.
- Do not declare reusable test doubles inside test suites or support factories.
- Use `TestSupport.waitUntil` for bounded asynchronous polling. Use `TestSupport.TestEventHub` for shared `AsyncStream` coordination.
- Add focused tests for changed behaviour, particularly for BLE lifecycle, persistence, protocol decoders, and measurement mapping.

## Before Handoff

Run the applicable commands from `docs/testing.md`. When regenerating the Xcode project, use `.xcodegen/generate-local.sh` if it exists so local signing settings are restored after `xcodegen generate`; never copy those local signing values into tracked files or final responses. For UI changes, inspect simulator output at the intended device/orientation before claiming the work is complete, and scan changed views for inline layout numbers that should be named constants. Do not commit build products, `xcuserdata`, local captures, provisioning files, or secrets.
