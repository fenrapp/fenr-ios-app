# Contributing

Thanks for improving FENR. Keep contributions focused, testable, and within the guarded vehicle-write boundary documented in `AGENTS.md`.

1. Read [AGENTS.md](AGENTS.md), [docs/architecture.md](docs/architecture.md), and the [Code of Conduct](CODE_OF_CONDUCT.md).
2. Open an issue first for substantial changes so the intended boundary is clear.
3. Follow [Development](docs/development.md) for setup. Regenerate the Xcode project when `project.yml` or source-file membership changes, using the local helper if present.
4. Add or update focused tests.
5. Run the checks in [docs/testing.md](docs/testing.md).
6. Keep pull requests small and describe user-facing effects, validation, and any remaining limitations.

Do not submit vendor-owned files, raw Bluetooth captures, credentials, private endpoints, APK material, or undocumented write/control functionality. Charging, base-map horsepower/regeneration, traction and bike-lock changes must retain their firmware and capability gates, no-op validation, sibling-value preservation, serialized operations, timeout recovery and fresh confirmation. Arbitrary configuration, custom curves, safety-control, ownership and firmware writes remain out of scope.

Use synthetic motorcycle identifiers and routes in examples and fixtures. Keep
feature copy in its String Catalog, and update the relevant documentation when
behavior or setup changes. See [Localization](docs/localization.md) for copy rules
and [Security](SECURITY.md) for private vulnerability reports.
