import Foundation

public struct RideNavigationTiming: Sendable {
    public let now: @Sendable () -> Date
    public let sleep: @Sendable (Duration) async throws -> Void

    public init(
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.now = now
        self.sleep = sleep
    }

    public static let live = RideNavigationTiming(
        now: Date.init,
        sleep: { duration in try await Task.sleep(for: duration) }
    )
}
