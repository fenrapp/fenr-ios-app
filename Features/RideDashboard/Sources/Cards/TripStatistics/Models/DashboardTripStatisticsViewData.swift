public struct DashboardTripStatisticsViewData: Equatable, Sendable {
    public let statusText: String
    public let totalDistance: Metric
    public let totalDuration: Metric
    public let averageSpeed: Metric
    public let maximumSpeed: Metric
    public let isLoading: Bool
    public let accessibilityLabel: String

    public init(
        statusText: String? = nil,
        totalDistance: Metric? = nil,
        totalDuration: Metric? = nil,
        averageSpeed: Metric? = nil,
        maximumSpeed: Metric? = nil,
        isLoading: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.statusText = statusText ?? rideDashboardLocalized(.rideDashboardTripStatisticsStatusNone)
        self.totalDistance = totalDistance ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricTotalDistance), valueText: "0", unit: "km"
        )
        self.totalDuration = totalDuration ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricRideTime), valueText: "00:00"
        )
        self.averageSpeed = averageSpeed ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricAverage), valueText: "0", unit: "km/h"
        )
        self.maximumSpeed = maximumSpeed ?? .init(
            label: rideDashboardLocalized(.rideDashboardMetricMaximumSpeed), valueText: "0", unit: "km/h"
        )
        self.isLoading = isLoading
        self.accessibilityLabel = accessibilityLabel
            ?? rideDashboardLocalized(.rideDashboardTripStatisticsAccessibilityNone)
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
