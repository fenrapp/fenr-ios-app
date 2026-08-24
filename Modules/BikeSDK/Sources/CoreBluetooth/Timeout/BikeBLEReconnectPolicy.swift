import Foundation
import RuntimeConfiguration

public struct BikeBLEReconnectPolicy: Equatable, Sendable {
    public let delays: [Duration]

    public init(delays: [Duration]) {
        self.delays = delays
    }

    public func delay(forAttempt attempt: Int) -> Duration? {
        guard attempt > 0, delays.indices.contains(attempt - 1) else { return nil }
        return delays[attempt - 1]
    }

    public static let standard = BikeBLEReconnectPolicy(
        delays: FENRRuntimeConstants.BikeSDK.reconnectDelays
    )
}
