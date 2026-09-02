# Localization

FENR uses Xcode String Catalogs and the Swift symbols generated from manually managed catalog entries. English is the source language. Each UI-producing target owns its `Localizable.xcstrings` file so generated resources resolve from the framework, app, Watch app, or extension bundle that presents them.

## Source rules

- Use semantic camel-case keys prefixed with the owning feature, for example `rideHistoryDeleteRides`.
- Reference copy with generated `LocalizedStringResource` symbols. Do not use raw localization keys.
- Keep complete sentences and accessibility descriptions in the catalog. Use named format arguments and catalog plural variations instead of assembling English fragments.
- Prefer `LocalizedStringResource` for app-authored presentation copy. Resolve it to `String` only at UIKit, LocalAuthentication, ActivityKit, filesystem, or other APIs that require a concrete string.
- Render external or user-provided text with a verbatim API so it is not mistaken for localizable copy.
- Use Foundation format styles for dates, durations, numbers, lists, and measurements.

The following literals are technical data rather than copy and stay in Swift: stable IDs and raw values, SF Symbol and asset names, URLs and schemes, persistence keys, file extensions, log formats, BLE payload text, accessibility identifiers, test fixtures, synthetic identifiers, and preview names. Copy rendered inside a preview should reuse the production catalog even though the preview's own name is developer metadata.

## Validation

`STRING_CATALOG_GENERATE_SYMBOLS`, `SWIFT_EMIT_LOC_STRINGS`, and `LOCALIZATION_PREFERS_STRING_CATALOGS` are enabled in `project.yml`. SwiftLint rejects direct user-facing literals in production UI APIs and raw `String(localized:)` keys. Build every affected target after editing a catalog so the generated API and owning bundle are checked by the compiler.
