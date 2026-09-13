import Foundation

public struct BikeUsageCounter: Equatable, Sendable {
    public let rawValue: UInt32
    public let sampledAt: Date

    public init(rawValue: UInt32, sampledAt: Date) {
        self.rawValue = rawValue
        self.sampledAt = sampledAt
    }
}
