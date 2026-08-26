public struct DashboardCurrentTripViewData: Equatable, Sendable {
    public let durationText: String
    public let statusText: String
    public let distance: Metric
    public let averageSpeed: Metric
    public let maximumSpeed: Metric
    public let speedSourceIndicator: DashboardSpeedSourceIndicatorViewData?
    public let isActive: Bool
    public let isPaused: Bool
    public let accessibilityLabel: String

    public init(
        durationText: String = "00:00:00",
        statusText: String = "STARTS IN GEAR",
        distance: Metric = .init(label: "DISTANCE", systemImage: "location"),
        averageSpeed: Metric = .init(label: "AVERAGE", systemImage: "speedometer"),
        maximumSpeed: Metric = .init(label: "MAX SPEED", systemImage: "arrow.up.right"),
        speedSourceIndicator: DashboardSpeedSourceIndicatorViewData? = nil,
        isActive: Bool = false,
        isPaused: Bool = false,
        accessibilityLabel: String = "Current trip has not started"
    ) {
        self.durationText = durationText
        self.statusText = statusText
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maximumSpeed = maximumSpeed
        self.speedSourceIndicator = speedSourceIndicator
        self.isActive = isActive
        self.isPaused = isPaused
        self.accessibilityLabel = accessibilityLabel
    }

    public struct Metric: Equatable, Sendable {
        public let label: String
        public let valueText: String
        public let unit: String
        public let systemImage: String

        public init(
            label: String,
            valueText: String = "0",
            unit: String = "",
            systemImage: String
        ) {
            self.label = label
            self.valueText = valueText
            self.unit = unit
            self.systemImage = systemImage
        }
    }
}
