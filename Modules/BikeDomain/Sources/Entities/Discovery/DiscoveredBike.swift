import Foundation

public struct DiscoveredBike: Equatable, Identifiable, Sendable {
    public let vin: String
    public let rssi: Int

    public var id: String { vin }

    public init(vin: String, rssi: Int) {
        self.vin = vin
        self.rssi = rssi
    }
}
