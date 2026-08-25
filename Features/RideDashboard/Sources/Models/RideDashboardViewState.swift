public struct RideDashboardViewState: Equatable, Sendable {
    public let speedometer: DashboardSpeedometerViewData
    public let battery: Battery
    public let odometer: DashboardMetricViewData
    public let gear: DashboardGearViewData
    public let powerMode: DashboardPowerModeViewData
    public let isCharging: Bool
    public let connectionDetail: String
    public let hasTelemetry: Bool
    public let indicators: [DashboardIndicatorViewData]

    public init(
        speedometer: DashboardSpeedometerViewData = .init(),
        battery: Battery = .init(),
        odometer: DashboardMetricViewData = .init(),
        gear: DashboardGearViewData = .init(),
        powerMode: DashboardPowerModeViewData = .init(),
        isCharging: Bool = false,
        connectionDetail: String = "Connect your bike from Diagnostics.",
        hasTelemetry: Bool = false,
        indicators: [DashboardIndicatorViewData] = []
    ) {
        self.speedometer = speedometer
        self.battery = battery
        self.odometer = odometer
        self.gear = gear
        self.powerMode = powerMode
        self.isCharging = isCharging
        self.connectionDetail = connectionDetail
        self.hasTelemetry = hasTelemetry
        self.indicators = indicators
    }

    public struct Battery: Equatable, Sendable {
        public let percentageText: String
        public let progress: Double
        public let emphasis: Emphasis
        public let accessibilityLabel: String

        public init(
            percentageText: String = "—",
            progress: Double = .zero,
            emphasis: Emphasis = .unavailable,
            accessibilityLabel: String = "Battery unavailable"
        ) {
            self.percentageText = percentageText
            self.progress = progress
            self.emphasis = emphasis
            self.accessibilityLabel = accessibilityLabel
        }

        public enum Emphasis: Equatable, Sendable {
            case unavailable
            case positive
            case warning
            case critical
        }
    }
}
