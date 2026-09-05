import Foundation

public struct DeviceHeadingSample: Equatable, Sendable {
    public let degrees: Double
    public let accuracyDegrees: Double
    public let observedAt: Date

    public init(degrees: Double, accuracyDegrees: Double, observedAt: Date) {
        self.degrees = degrees
        self.accuracyDegrees = accuracyDegrees
        self.observedAt = observedAt
    }
}
