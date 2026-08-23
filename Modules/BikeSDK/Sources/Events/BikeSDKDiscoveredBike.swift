import Foundation

public struct BikeSDKDiscoveredBike: Equatable, Sendable {
    public let vin: String
    public let rssi: Int

    public init(vin: String, rssi: Int) {
        self.vin = vin
        self.rssi = rssi
    }
}
