public struct BatteryHealthViewState: Equatable, Sendable {
    public var summary: [BatteryHealthMetricViewData]
    public var charging: [BatteryHealthMetricViewData]
    public var packStatus: [BatteryHealthMetricViewData]
    public var cells: [BatteryCellViewData]
    public var temperatures: [BatteryTemperatureViewData]
    public var datasets: [BatteryHealthDatasetViewData]
    public var chargePowerControl: ChargePowerControlViewState
    public var isMonitoring: Bool
    public var monitorError: String?

    public init(
        summary: [BatteryHealthMetricViewData] = [],
        charging: [BatteryHealthMetricViewData] = [],
        packStatus: [BatteryHealthMetricViewData] = [],
        cells: [BatteryCellViewData] = [],
        temperatures: [BatteryTemperatureViewData] = [],
        datasets: [BatteryHealthDatasetViewData] = [],
        chargePowerControl: ChargePowerControlViewState = .init(),
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
