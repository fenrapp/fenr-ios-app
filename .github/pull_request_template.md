## Summary

## Validation

- [ ] Project regenerated when needed (use `.xcodegen/generate-local.sh` if present).
- [ ] `swiftlint lint --strict`
- [ ] Relevant tests
- [ ] Simulator/device UI inspection where applicable

## Safety boundary

- [ ] Vehicle-control changes preserve firmware/capability gates, no-op validation, sibling values, serialization, timeout recovery and fresh confirmation.
- [ ] No unsupported vehicle writes are introduced; physical validation claims match available evidence.
- [ ] No captures, credentials, private endpoints, or vendor-owned material are included.
- [ ] User-facing copy is catalog-backed and affected documentation is current.
