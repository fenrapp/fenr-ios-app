# iPhone performance validation

Status: paired baseline/candidate comparison pending. No performance sign-off.

Use production FENR in Release, one dedicated iPhone 17 simulator with iOS 26.5,
a clean app installation and the unchanged system text setting. Measure launch
until responsive, CPU time, physical memory and logical disk writes during the
same idle interval, then public-demo Settings scrolling. Repeat both builds on
the same otherwise idle host and report sample counts and variation.

Keep executable/framework hashes, raw metrics, screenshots, instrument traces
and per-run notes outside Git in `build/testflight-qa/`. The earlier preliminary
baseline diary is retained under `cleanup-history/`; it has no paired candidate
measurement and establishes no improvement or regression.

Simulator measurements do not establish physical-device cold boot, battery use,
Bluetooth traffic, dashboard frame pacing or background execution. Record these
limits alongside the final results. Never infer smoothness from idle metrics.
