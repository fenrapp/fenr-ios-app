import Foundation

public struct DeviceSpeedSample: Equatable, Sendable {
    public let kilometersPerHour: Double
    public let accuracyMetersPerSecond: Double
    public let observedAt: Date

    public init(
        kilometersPerHour: Double,
        accuracyMetersPerSecond: Double,
        observedAt: Date
    ) {
        self.kilometersPerHour = kilometersPerHour
        self.accuracyMetersPerSecond = accuracyMetersPerSecond
        self.observedAt = observedAt
    }
}
