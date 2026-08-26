public struct RideDashboardViewState: Equatable, Sendable {
    public let speedometer: DashboardSpeedometerViewData
    public let battery: Battery
    public let gear: DashboardGearViewData
    public let powerMode: DashboardPowerModeViewData
    public let centerMode: CenterMode
    public let connectionDetail: String
    public let hasTelemetry: Bool
    public let indicators: [DashboardIndicatorViewData]

    public init(
        speedometer: DashboardSpeedometerViewData = .init(),
        battery: Battery = .init(),
        gear: DashboardGearViewData = .init(),
        powerMode: DashboardPowerModeViewData = .init(),
        centerMode: CenterMode = .riding,
        connectionDetail: String = "Connect your bike from Diagnostics.",
        hasTelemetry: Bool = false,
        indicators: [DashboardIndicatorViewData] = []
    ) {
        self.speedometer = speedometer
        self.battery = battery
        self.gear = gear
        self.powerMode = powerMode
        self.centerMode = centerMode
        self.connectionDetail = connectionDetail
        self.hasTelemetry = hasTelemetry
        self.indicators = indicators
    }

    public enum CenterMode: Hashable, Sendable {
        case riding
        case charging
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
