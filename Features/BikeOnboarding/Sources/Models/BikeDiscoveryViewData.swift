public struct BikeDiscoveryViewData: Equatable, Identifiable, Sendable {
    public var id: String { vin }

    public let vin: String
    public let formattedVIN: String
    public let accessibilityVIN: String
    public let modelTitle: String
    public let rssiText: String
    public let signalText: String
    public let signalLevel: Int

    public init(
        vin: String,
        formattedVIN: String? = nil,
        accessibilityVIN: String? = nil,
        modelTitle: String,
        rssiText: String,
        signalText: String,
        signalLevel: Int
    ) {
        self.vin = vin
        self.formattedVIN = formattedVIN ?? Self.formatVIN(vin)
        self.accessibilityVIN = accessibilityVIN ?? Self.formatAccessibleVIN(vin)
        self.modelTitle = modelTitle
        self.rssiText = rssiText
        self.signalText = signalText
        self.signalLevel = signalLevel
    }

    static func formatVIN(_ vin: String) -> String {
        let characters = Array(vin)
        guard characters.count > 12 else { return vin }
        return [
            String(characters[0 ..< 4]),
            String(characters[4 ..< 8]),
            String(characters[8 ..< 12]),
            String(characters[12...])
        ].joined(separator: " ")
    }

    static func formatAccessibleVIN(_ vin: String) -> String {
        vin.map(String.init).joined(separator: " ")
    }
}
