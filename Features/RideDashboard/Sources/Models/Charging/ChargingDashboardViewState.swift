public struct ChargingDashboardViewState: Equatable, Sendable {
    public let batteryPercent: Int?
    public let targetPercent: Int?
    public let estimatedTimeRemaining: String?
    public let isBalancingAtFullCharge: Bool
    public let readout: ChargingDashboardReadoutViewData
    public let control: ChargingDashboardControlViewState
    public let maximumPower: DashboardMetricViewData
    public let chargingPower: DashboardMetricViewData
    public let reportedCurrent: DashboardMetricViewData
    public let batteryTemperature: DashboardMetricViewData
    public let batteryTemperatureEmphasis: TemperatureEmphasis
    public let activeBalancingCells: DashboardMetricViewData

    public init(
        batteryPercent: Int? = nil,
        targetPercent: Int? = nil,
        estimatedTimeRemaining: String? = nil,
        isBalancingAtFullCharge: Bool = false,
        readout: ChargingDashboardReadoutViewData = .init(),
        control: ChargingDashboardControlViewState = .init(),
        maximumPower: DashboardMetricViewData = .init(),
        chargingPower: DashboardMetricViewData = .init(),
        reportedCurrent: DashboardMetricViewData = .init(),
        batteryTemperature: DashboardMetricViewData = .init(),
        batteryTemperatureEmphasis: TemperatureEmphasis = .unavailable,
        activeBalancingCells: DashboardMetricViewData = .init()
    ) {
        self.batteryPercent = batteryPercent
        self.targetPercent = targetPercent
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.isBalancingAtFullCharge = isBalancingAtFullCharge
        self.readout = readout
        self.control = control
        self.maximumPower = maximumPower
        self.chargingPower = chargingPower
        self.reportedCurrent = reportedCurrent
        self.batteryTemperature = batteryTemperature
        self.batteryTemperatureEmphasis = batteryTemperatureEmphasis
        self.activeBalancingCells = activeBalancingCells
    }

    public enum TemperatureEmphasis: Equatable, Sendable {
        case unavailable
        case normal
        case warning
        case critical
    }
}
