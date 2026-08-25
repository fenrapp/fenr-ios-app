public struct ChargingDashboardViewState: Equatable, Sendable {
    public let gauge: ChargingDashboardGaugeViewState
    public let maximumPower: DashboardMetricViewData
    public let reportedCurrent: DashboardMetricViewData
    public let batteryTemperature: DashboardMetricViewData

    public init(
        gauge: ChargingDashboardGaugeViewState = .init(),
        maximumPower: DashboardMetricViewData = .init(),
        reportedCurrent: DashboardMetricViewData = .init(),
        batteryTemperature: DashboardMetricViewData = .init()
    ) {
        self.gauge = gauge
        self.maximumPower = maximumPower
        self.reportedCurrent = reportedCurrent
        self.batteryTemperature = batteryTemperature
    }
}
