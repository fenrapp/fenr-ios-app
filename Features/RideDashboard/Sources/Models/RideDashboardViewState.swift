public struct RideDashboardViewState: Equatable, Sendable {
    public let speedometer: DashboardSpeedometerViewData
    public let showsCompactSpeedReadout: Bool
    public let odometer: DashboardOdometerViewData
    public let progressBar: DashboardProgressBarViewData
    public let progressBarLayout: DashboardProgressBarLayout
    public let battery: Battery
    public let showsEstimatedRangeBatteryIndicator: Bool
    public let temperatureSummary: TemperatureSummary
    public let gear: DashboardGearViewData
    public let powerMode: DashboardPowerModeViewData
    public let centerMode: CenterMode
    public let connectionDetail: String
    public let hasTelemetry: Bool
    public let showsConnectionProgress: Bool
    public let continuityPhase: RideDashboardContinuityPhase
    public let connectionNotice: DashboardConnectionNoticeViewData?
    public let indicators: [DashboardIndicatorViewData]

    public init(
        speedometer: DashboardSpeedometerViewData = .init(),
        showsCompactSpeedReadout: Bool = false,
        odometer: DashboardOdometerViewData = .init(),
        progressBar: DashboardProgressBarViewData = .neutralEnergy,
        progressBarLayout: DashboardProgressBarLayout = .regular,
        battery: Battery = .init(),
        showsEstimatedRangeBatteryIndicator: Bool = false,
        temperatureSummary: TemperatureSummary = .init(),
        gear: DashboardGearViewData = .init(),
        powerMode: DashboardPowerModeViewData = .init(),
        centerMode: CenterMode = .riding,
        connectionDetail: String? = nil,
        hasTelemetry: Bool = false,
        showsConnectionProgress: Bool = true,
        continuityPhase: RideDashboardContinuityPhase = .cold,
        connectionNotice: DashboardConnectionNoticeViewData? = nil,
        indicators: [DashboardIndicatorViewData] = []
    ) {
        self.speedometer = speedometer
        self.showsCompactSpeedReadout = showsCompactSpeedReadout
        self.odometer = odometer
        self.progressBar = progressBar
        self.progressBarLayout = progressBarLayout
        self.battery = battery
        self.showsEstimatedRangeBatteryIndicator = showsEstimatedRangeBatteryIndicator
        self.temperatureSummary = temperatureSummary
        self.gear = gear
        self.powerMode = powerMode
        self.centerMode = centerMode
        self.connectionDetail = connectionDetail ?? rideDashboardLocalized(.rideDashboardConnectionRestoring)
        self.hasTelemetry = hasTelemetry
        self.showsConnectionProgress = showsConnectionProgress
        self.continuityPhase = continuityPhase
        self.connectionNotice = connectionNotice
        self.indicators = indicators
    }

    func waitingForStableTelemetry() -> Self {
        .init(
            progressBarLayout: progressBarLayout,
            showsEstimatedRangeBatteryIndicator: showsEstimatedRangeBatteryIndicator,
            connectionDetail: rideDashboardLocalized(.rideDashboardConnectionVerifying),
            showsConnectionProgress: true,
            continuityPhase: .cold
        )
    }

    func withContinuity(
        _ phase: RideDashboardContinuityPhase,
        notice: DashboardConnectionNoticeViewData? = nil,
        powerMode: DashboardPowerModeViewData? = nil
    ) -> Self {
        .init(
            speedometer: speedometer,
            showsCompactSpeedReadout: showsCompactSpeedReadout,
            odometer: odometer,
            progressBar: progressBar,
            progressBarLayout: progressBarLayout,
            battery: battery,
            showsEstimatedRangeBatteryIndicator: showsEstimatedRangeBatteryIndicator,
            temperatureSummary: temperatureSummary,
            gear: gear,
            powerMode: powerMode ?? self.powerMode,
            centerMode: centerMode,
            connectionDetail: connectionDetail,
            hasTelemetry: hasTelemetry,
            showsConnectionProgress: showsConnectionProgress,
            continuityPhase: phase,
            connectionNotice: notice,
            indicators: indicators
        )
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
            accessibilityLabel: String? = nil
        ) {
            self.percentageText = percentageText
            self.progress = progress
            self.emphasis = emphasis
            self.accessibilityLabel = accessibilityLabel
                ?? rideDashboardLocalized(.rideDashboardBatteryUnavailableAccessibility)
        }

        public enum Emphasis: Equatable, Sendable {
            case unavailable
            case positive
            case warning
            case critical
        }
    }

    public struct TemperatureSummary: Equatable, Sendable {
        public let batteryTemperatureText: String?
        public let inverterTemperatureText: String?

        public init(
            batteryTemperatureText: String? = nil,
            inverterTemperatureText: String? = nil
        ) {
            self.batteryTemperatureText = batteryTemperatureText
            self.inverterTemperatureText = inverterTemperatureText
        }
    }
}
