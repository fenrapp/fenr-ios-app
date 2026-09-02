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
        statusText: String? = nil,
        distance: Metric? = nil,
        averageSpeed: Metric? = nil,
        maximumSpeed: Metric? = nil,
        speedSourceIndicator: DashboardSpeedSourceIndicatorViewData? = nil,
        isActive: Bool = false,
        isPaused: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.durationText = durationText
        self.statusText = statusText ?? rideDashboardLocalized(.rideDashboardCurrentTripStatusStartsInGear)
        self.distance = distance ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricDistance),
            systemImage: "location"
        )
        self.averageSpeed = averageSpeed ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricAverage),
            systemImage: "speedometer"
        )
        self.maximumSpeed = maximumSpeed ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricMaximumSpeed),
            systemImage: "arrow.up.right"
        )
        self.speedSourceIndicator = speedSourceIndicator
        self.isActive = isActive
        self.isPaused = isPaused
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardCurrentTripAccessibilityNotStarted)
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
