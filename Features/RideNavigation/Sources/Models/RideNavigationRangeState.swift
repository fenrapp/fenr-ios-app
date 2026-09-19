import Foundation

public struct RideNavigationRangeState: Equatable, Sendable {
    public let value: String
    public let unit: String

    public init(value: String = "--", unit: String = "") {
        self.value = value
        self.unit = unit
    }
}
