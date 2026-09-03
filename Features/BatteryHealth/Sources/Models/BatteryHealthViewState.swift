public struct BatteryHealthViewState: Equatable, Sendable {
    public let overview: BatteryHealthOverviewViewData
    public let cellsDetail: BatteryHealthCellsViewData
    public let thermalDetail: BatteryHealthThermalViewData
    public let chargingDetail: BatteryHealthChargingViewData
    public let rawDataDetail: BatteryHealthRawDataViewData
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
        overview: BatteryHealthOverviewViewData = .init(),
        cellsDetail: BatteryHealthCellsViewData = .init(),
        thermalDetail: BatteryHealthThermalViewData = .init(),
        chargingDetail: BatteryHealthChargingViewData = .init(),
        rawDataDetail: BatteryHealthRawDataViewData = .init(),
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
        self.overview = overview
        self.cellsDetail = cellsDetail
        self.thermalDetail = thermalDetail
        self.chargingDetail = chargingDetail
        self.rawDataDetail = rawDataDetail
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
