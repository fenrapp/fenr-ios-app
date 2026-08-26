public struct DashboardTripStatisticsViewData: Equatable, Sendable {
    public let statusText: String
    public let totalDistance: Metric
    public let totalDuration: Metric
    public let averageSpeed: Metric
    public let maximumSpeed: Metric
    public let isLoading: Bool
    public let accessibilityLabel: String

    public init(
        statusText: String = "NO SAVED TRIPS",
        totalDistance: Metric = .init(label: "TOTAL DISTANCE", valueText: "0", unit: "km"),
        totalDuration: Metric = .init(label: "RIDE TIME", valueText: "00:00"),
        averageSpeed: Metric = .init(label: "AVERAGE", valueText: "0", unit: "km/h"),
        maximumSpeed: Metric = .init(label: "MAX SPEED", valueText: "0", unit: "km/h"),
        isLoading: Bool = false,
        accessibilityLabel: String = "Ride statistics, no saved trips"
    ) {
        self.statusText = statusText
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.averageSpeed = averageSpeed
        self.maximumSpeed = maximumSpeed
        self.isLoading = isLoading
        self.accessibilityLabel = accessibilityLabel
    }

    public struct Metric: Equatable, Sendable {
        public let label: String
        public let valueText: String
        public let unit: String

        public init(label: String, valueText: String, unit: String = "") {
            self.label = label
            self.valueText = valueText
            self.unit = unit
        }
    }
}
