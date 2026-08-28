# Contributing

Thanks for improving FENR. Keep contributions focused, testable, and within the guarded vehicle-write boundary documented in `AGENTS.md`.

1. Read [AGENTS.md](AGENTS.md), [docs/architecture.md](docs/architecture.md), and the [Code of Conduct](CODE_OF_CONDUCT.md).
2. Open an issue first for substantial changes so the intended boundary is clear.
3. Regenerate the Xcode project when `project.yml` changes.
4. Add or update focused tests.
5. Run the checks in [docs/testing.md](docs/testing.md).
6. Keep pull requests small and describe user-facing effects, validation, and any remaining limitations.

Do not submit vendor-owned files, raw Bluetooth captures, credentials, private endpoints, APK material, or undocumented write/control functionality. Base-map horsepower, regenerative-braking, TC, and TC Regen changes must retain their independent firmware, no-op, sibling-preservation, serialization, and fresh-read confirmation flow. Arbitrary configuration, custom curves, safety-control, lock, ownership, and firmware writes remain out of scope.
