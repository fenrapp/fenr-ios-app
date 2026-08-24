# FENR Agent Guide

## Scope

FENR is an iPhone and Apple Watch dashboard and diagnostics app for compatible electric motorcycles, with a narrowly scoped authenticated VCU write surface for verified charging-power and charge-target configuration. Keep vehicle writes limited to protocol behavior confirmed by clean-room evidence and physical telemetry, with firmware gates, no-op validation, serialized operations, value preservation, timeout handling, and telemetry confirmation. Do not add arbitrary configuration writes or commands that modify riding maps, vehicle behavior, safety controls, or firmware. Do not add raw captures, credentials, APKs, copied vendor assets, private endpoints, or research notes to this repository.

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

- Structure new UI like the existing feature modules: put screens in `UI/`, reusable view pieces in `UI/Components/`, layout helpers in `UI/Layout/`, UI state helpers in `UI/State/`, previews in `UI/Previews/`, and formatting/text/presentation helpers in `UI/Support` or the existing local folder that matches the feature. When a feature's `UI/Components/` grows beyond a few files, organize it into focused category folders such as `Navigation`, `Feedback`, `Inputs`, `Rows`, `Surfaces`, or domain-specific groups instead of leaving a flat components directory.
- Before creating a new UI component, design token, formatter, color, spacing scale, radius, font wrapper, or presentation helper, search the feature and `Modules/DesignSystem` for an existing equivalent and reuse it when it fits.
- Use `DesignSystem` for shared SwiftUI colors, spacing, radii, surfaces, and common reusable components. Only create feature-specific constants for values that are genuinely local to that feature or component.
- Split non-trivial SwiftUI views into focused components. Do not collect unrelated UI pieces in broad files such as `Components.swift`, `Views.swift`, or `Style.swift`.
- Keep feature-specific layout/style/text constants in a named constants type owned by the component or feature. Do not leave magic numbers inline in view bodies or modifiers.

## Coding Rules

- Follow existing module boundaries and local patterns before adding abstractions.
- Keep dependency construction in an explicit composition root, dependency container, assembly, or factory. Initializers for coordinators, services, repositories, transports, queues, schedulers, controllers, and view models must receive their collaborators and only assign them; do not instantiate hidden collaborators inside those initializers.
- Inject collaborators even when they are value types or stateless utilities. Do not initialize log stores, normalizers, formatters, mappers, schedulers, transports, controllers, or similar dependencies in stored-property declarations or inside the consuming object. Direct initialization is reserved for the object's own primitive runtime state and collections that do not represent a replaceable collaborator.
- Construct complete object graphs in one phase. Avoid setter injection, post-init callback wiring, and other two-phase initialization when the dependency or handler can be supplied at construction time.
- Keep transient presentation state such as dragging, focus, hover, and gesture phases inside the SwiftUI view. View models and coordinators receive semantic intents or final values, not control lifecycle callbacks, unless the interaction phase is itself domain behavior.
- Prefer immutable value types: use `struct` or `enum` with `let` properties when a type only groups dependencies, configuration, input, output, or stateless behavior. Use a reference type only when identity, shared mutable state, cancellation/lifecycle ownership, weak references, continuations, caching, delegate interoperability, or another concrete reference semantic is required.
- During review and cleanup passes, inspect the touched code for hidden dependency construction, unnecessary reference types, and two-phase initialization. Refactor these issues when they are within the task's scope and keep behavior protected by existing or focused new tests; do not expand into unrelated modules solely to apply the rule mechanically.
- Use typed branch prefixes for agent work: `feature/<name>` for product changes, `qa/fixes/<name>` for test or validation fixes, `bugfix/<name>` for defects, `chore/<name>` for maintenance, and `research/<name>` for protocol investigation that does not ship app behaviour.
- Keep UI text in English.
- Use `StarkPairingIdentity` as the only VIN normalization/validation utility.
- Treat user-provided VINs and real motorcycle identifiers as sensitive data. Never copy them into source, tests, previews, docs, commit messages, logs, or final responses; use synthetic VINs such as `FENRTEST000000001` or shared debug constants instead.
- Preserve the app-wide single BLE session. Navigating between dashboard, settings, diagnostics, and battery health must not create competing telemetry connections.
- The Watch app has its own direct Bluetooth session and declares Bluetooth background support. Preserve one Watch session and its restoration policy, and do not route its runtime dependency through a paired iPhone.
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
