public struct BatteryHealthViewState: Equatable, Sendable {
    public let summary: [BatteryHealthMetricViewData]
    public let charging: [BatteryHealthMetricViewData]
    public let packStatus: [BatteryHealthMetricViewData]
    public let cells: [BatteryCellViewData]
    public let temperatures: [BatteryTemperatureViewData]
    public let datasets: [BatteryHealthDatasetViewData]
    public let chargePowerControl: BatteryHealthChargeControlViewState
    public let isMonitoring: Bool
    public let monitorError: String?

    public init(
        summary: [BatteryHealthMetricViewData] = [],
        charging: [BatteryHealthMetricViewData] = [],
        packStatus: [BatteryHealthMetricViewData] = [],
        cells: [BatteryCellViewData] = [],
        temperatures: [BatteryTemperatureViewData] = [],
        datasets: [BatteryHealthDatasetViewData] = [],
        chargePowerControl: BatteryHealthChargeControlViewState = .init(),
        isMonitoring: Bool = false,
        monitorError: String? = nil
    ) {
        self.summary = summary
        self.charging = charging
        self.packStatus = packStatus
        self.cells = cells
        self.temperatures = temperatures
        self.datasets = datasets
        self.chargePowerControl = chargePowerControl
        self.isMonitoring = isMonitoring
        self.monitorError = monitorError
    }
}
