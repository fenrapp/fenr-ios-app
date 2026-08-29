# FENR Agent Guide

## Scope

FENR is an iPhone and Apple Watch dashboard and diagnostics app for compatible electric motorcycles. Its authenticated VCU write surface includes verified charging-power and charge-target configuration plus guarded horsepower, regenerative-braking, traction-control, regen-traction, and bike-lock control. Keep every vehicle write behind firmware and capability gates, safe no-op validation, serialized operations, complete sibling-value preservation, timeout recovery, and telemetry or fresh-read confirmation. Base-map reads may report curve selector `0`; accept only `0` or `mapIndex + 1`, and normalize every base-map write to `mapIndex + 1` while preserving torque and regeneration. Traction-control type `8` requires VCU PIC firmware 1.10.1 or newer, an exact no-op, and exact confirmation of both signed tenths-of-a-percent values. Base-map writes have physical write/read-back evidence; do not claim physical traction-control or bike-lock write validation until equivalent evidence exists. Do not expand this work to arbitrary configuration, custom curves, safety-control, ownership, or firmware writes. Do not add raw captures, credentials, APKs, copied vendor assets, private endpoints, or research notes to this repository.

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
- Keep every visual component isolated from vehicle and infrastructure modules. Files under `UI/` must not import or reference Bike/SDK, protocol, data, repository, use-case, transport, or persistence modules and types, including indirectly through their input properties.
- Views consume only immutable feature-owned presentation models and emit semantic intents or final user-selected values through closures or view-model methods. Do not expose domain/SDK entities as view state and do not make a view perform domain-to-presentation mapping.
- View models coordinate use cases and user intents; injected mappers translate domain or SDK output into feature-owned view state before publication. Map UI input back into semantic commands at the view-model boundary, then remap resulting state for the view. Keep transient control mechanics such as drag position inside SwiftUI.
- Shape view state for the screen instead of mirroring domain or SDK models one-to-one. Mappers may combine fields, format values, resolve labels and presentation status, group rows, omit irrelevant data, and expose action availability so views can render directly without reconstructing business or presentation rules.
- Do not create UI enums or structs that merely duplicate every case or property of a domain type. Keep raw numeric values only when a native UI control or transient interaction genuinely needs them; otherwise publish display-ready text, progress, emphasis, visibility, and other feature-owned presentation data.
- Keep each top-level presentation model in its own correspondingly named file. Place ordinary view-state and view-data types directly under the feature's `Models/` folder; introduce semantic subfolders such as `Models/Charging/` only when several related models form a distinct presentation area. Closely owned nested types may remain with their parent.

## Coding Rules

- Follow existing module boundaries and local patterns before adding abstractions.
- Keep dependency construction in an explicit composition root, dependency container, assembly, or factory. Initializers for coordinators, services, repositories, transports, queues, schedulers, controllers, and view models must receive their collaborators and only assign them; do not instantiate hidden collaborators inside those initializers.
- Inject collaborators even when they are value types or stateless utilities. Do not initialize log stores, normalizers, formatters, mappers, schedulers, transports, controllers, or similar dependencies in stored-property declarations or inside the consuming object. Direct initialization is reserved for the object's own primitive runtime state and collections that do not represent a replaceable collaborator.
- Construct complete object graphs in one phase. Avoid setter injection, post-init callback wiring, and other two-phase initialization when the dependency or handler can be supplied at construction time.
- Keep transient presentation state such as dragging, focus, hover, and gesture phases inside the SwiftUI view. View models and coordinators receive semantic intents or final values, not control lifecycle callbacks, unless the interaction phase is itself domain behavior.
- Prefer Foundation's immutable system format styles, including `Date.FormatStyle`, `Duration.TimeFormatStyle`, `Duration.UnitsFormatStyle`, number, percent, currency, measurement, byte-count, and list styles, before creating a custom formatter. Add a feature formatter only when it owns meaningful domain-to-presentation mapping, and have it delegate primitive formatting to the appropriate system style.
- Prefer immutable value types: use `struct` or `enum` with `let` properties when a type only groups dependencies, configuration, input, output, or stateless behavior. Use a reference type only when identity, shared mutable state, cancellation/lifecycle ownership, weak references, continuations, caching, delegate interoperability, or another concrete reference semantic is required.
- Treat every unstructured `Task` as owned lifecycle state. Store it on the object responsible for the operation, cancel or await the previous task before replacing it, cancel it on stop, disconnect, reset, or `deinit` as appropriate, and guard state mutations after suspension against cancellation and stale connection/session generations. Do not launch fire-and-forget tasks unless the operation must deliberately outlive its caller; make that ownership explicit and cover restart, cancellation, and teardown behavior with focused tests.
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
