import Foundation

public struct BikeOnboardingTiming: Sendable {
    public let sleep: @Sendable (Duration) async throws -> Void

    public init(sleep: @escaping @Sendable (Duration) async throws -> Void) {
        self.sleep = sleep
    }

    public static let live = BikeOnboardingTiming { duration in
        try await Task.sleep(for: duration)
    }
}
