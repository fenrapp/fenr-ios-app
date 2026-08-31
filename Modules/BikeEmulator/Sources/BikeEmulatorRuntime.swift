import Foundation
import RuntimeConfiguration

struct BikeEmulatorRuntime: Sendable {
    let now: @Sendable () async -> Date
    let sleep: @Sendable (Duration) async throws -> Void
    let telemetryInterval: Duration
    let imuInterval: Duration

    static let live = BikeEmulatorRuntime(
        now: { Date() },
        sleep: { duration in try await Task.sleep(for: duration) },
        telemetryInterval: FENRRuntimeConstants.Emulator.updateInterval,
        imuInterval: .milliseconds(100)
    )
}
