public struct RideDashboardViewState: Equatable, Sendable {
    public let speedometer: DashboardSpeedometerViewData
    public let batteryPercent: Int?
    public let odometer: DashboardMetricViewData
    public let gear: DashboardGearViewData
    public let isCharging: Bool
    public let connectionDetail: String
    public let hasTelemetry: Bool
    public let indicators: [DashboardIndicatorViewData]

    public init(
        speedometer: DashboardSpeedometerViewData = .init(),
        batteryPercent: Int? = nil,
        odometer: DashboardMetricViewData = .init(),
        gear: DashboardGearViewData = .init(),
        isCharging: Bool = false,
        connectionDetail: String = "Connect your bike from Diagnostics.",
        hasTelemetry: Bool = false,
        indicators: [DashboardIndicatorViewData] = []
    ) {
        self.speedometer = speedometer
        self.batteryPercent = batteryPercent
        self.odometer = odometer
        self.gear = gear
        self.isCharging = isCharging
        self.connectionDetail = connectionDetail
        self.hasTelemetry = hasTelemetry
        self.indicators = indicators
    }
}
