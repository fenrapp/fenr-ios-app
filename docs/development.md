# Development

## Requirements

- Xcode 26 or later, including the iOS and watchOS SDKs used by the project.
- XcodeGen 2.42.0 or later: `brew install xcodegen`.
- SwiftLint: `brew install swiftlint`.
- Python 3 for the project-generation hook and resource-validation scripts.

Deployment targets are iOS 17 and watchOS 10. These are the minimum operating
systems for the apps, not the required SDK versions. Liquid Glass uses the iOS 26
SDK and is isolated behind availability checks with earlier-system fallbacks.
String Catalog symbols also require the modern toolchain.

## Generate the project

`project.yml` is the entry point for generating `FENR.xcodeproj`. It keeps global
settings and includes the shared specifications in `config/xcodegen/`:

- `modules.yml` defines supporting framework targets.
- `features.yml` defines presentation framework targets, including Watch features.
- `apps.yml` defines iPhone and Watch apps and their extensions.
- `tests.yml` defines unit-test targets.
- `schemes.yml` keeps the four shared schemes and their explicit test lists.
- `templates.yml` shares framework and unit-test type/platform settings.

All paths in these specifications are relative to the repository root. Add a
target to its owning specification and keep its dependencies, bundle identifier
and source/resource paths explicit. Apply an existing template when its platform
matches, and add new tests to the relevant scheme's build and test lists.

```sh
if [ -x .xcodegen/generate-local.sh ]; then
  .xcodegen/generate-local.sh
else
  xcodegen generate
fi
open FENR.xcodeproj
```

The optional local helper restores the developer's signing configuration after
generation. `.xcodegen/` is ignored. A fresh clone uses XcodeGen directly; configure
your own team for physical-device builds and keep signing values out of commits.
Regenerate after adding, removing or moving source files as well as after editing
any project specification; XcodeGen discovers target sources from the configured
directories. Keep shared specifications in `config/xcodegen/`; the ignored
`.xcodegen/` directory is reserved for local helpers and signing configuration.

## Schemes

| Scheme | Purpose |
| --- | --- |
| `FENR` | Production iPhone app, public demo, Share and Live Activity extensions. |
| `FENRDebug` | Emulator-backed iPhone development app, without motorcycle hardware. |
| `FENRWatch` | Independent, telemetry-only Watch app with direct Bluetooth. |
| `FENRWatchDebug` | Emulator-backed Watch app; starts in the charging scenario. |

The iPhone app does not embed the Watch app. The first distribution is iPhone-only;
the Watch implementation remains available for development.

For the public demo, launch `FENR` and choose **Explore demo > Start demo**. Its
motorcycle data and saved records are isolated from real-bike storage. Navigation
still uses actual location and Apple Maps services. See the
[demo guide](app-review-demo.md) and [testing commands](testing.md).

## Working with a motorcycle

The observed VCU accepts one active Bluetooth client. Disconnect the Arkenstone
phone and other clients before testing. Preserve one iPhone session across all
screens; the Watch owns its own session and competes for the same vehicle link.

Vehicle writes are limited to charging power/target, base-map power/regeneration,
traction settings, bike lock and iPhone advanced power/regeneration curves. Keep firmware and capability gates, safe no-op
validation, serialized operations, sibling-value preservation, timeout recovery
and fresh confirmation intact. Charging controls and base-map changes have
physical validation evidence. Instrumented physical advanced-curve, traction-control and lock
write/read-back evidence remains incomplete; emulator tests do not establish it.

Keep packet layouts and evidence in the
[protocol research repository](https://github.com/fenrapp/bike-protocol-research).
Do not add arbitrary configuration, safety-control, ownership or
firmware writes. Repository implementation rules are in [AGENTS.md](../AGENTS.md).

## Diagnostic capture

Capture is opt-in through **Start** and **Stop** in Diagnostics and is disabled
at every process launch. It can start while disconnected and continue across
reconnection to the same motorcycle. Telemetry and vehicle confirmations work
without recording. Keep exported logs, captures and build results outside Git.
