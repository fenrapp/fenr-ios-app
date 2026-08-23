public struct BLEConnectionIntent: Equatable, Sendable {
    public let vin: String
    public let shouldReconnect: Bool

    public init(vin: String, shouldReconnect: Bool) {
        self.vin = vin
        self.shouldReconnect = shouldReconnect
    }
}
