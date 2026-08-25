public struct WatchDiscoveredBikeViewData: Equatable, Identifiable, Sendable {
    public var id: String { vin }
    public let vin: String
    public let signalText: String

    public init(vin: String, signalText: String) {
        self.vin = vin
        self.signalText = signalText
    }
}
