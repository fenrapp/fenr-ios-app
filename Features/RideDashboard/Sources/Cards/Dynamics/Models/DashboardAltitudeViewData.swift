public struct DashboardAltitudeViewData: Equatable, Sendable {
    public struct Tick: Equatable, Identifiable, Sendable {
        public let id: Double
        public let label: String?
        public let position: Double
    }

    public let valueText: String
    public let unitText: String
    public let minimumText: String
    public let maximumText: String
    public let ticks: [Tick]
    public let isAvailable: Bool

    public init(
        valueText: String = "\u{2014}",
        unitText: String = "",
        minimumText: String = "\u{2014}",
        maximumText: String = "\u{2014}",
        ticks: [Tick] = [],
        isAvailable: Bool = false
    ) {
        self.valueText = valueText
        self.unitText = unitText
        self.minimumText = minimumText
        self.maximumText = maximumText
        self.ticks = ticks
        self.isAvailable = isAvailable
    }
}
