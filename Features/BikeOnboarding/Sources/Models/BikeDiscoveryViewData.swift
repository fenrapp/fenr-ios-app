public struct BikeDiscoveryViewData: Equatable, Identifiable, Sendable {
    public var id: String { vin }
    public let vin: String
    public let signalText: String
    public let isSelected: Bool

    public init(vin: String, signalText: String, isSelected: Bool) {
        self.vin = vin
        self.signalText = signalText
        self.isSelected = isSelected
    }
}
