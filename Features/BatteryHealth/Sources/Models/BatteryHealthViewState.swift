public struct BatteryHealthViewState: Equatable, Sendable {
    public let overview: BatteryHealthOverviewViewData
    public let cellsDetail: BatteryHealthCellsViewData
    public let thermalDetail: BatteryHealthThermalViewData
    public let chargingDetail: BatteryHealthChargingViewData
    public let rawDataDetail: BatteryHealthRawDataViewData
    public let isMonitoring: Bool
    public let monitorError: String?

    public init(
        overview: BatteryHealthOverviewViewData = .init(),
        cellsDetail: BatteryHealthCellsViewData = .init(),
        thermalDetail: BatteryHealthThermalViewData = .init(),
        chargingDetail: BatteryHealthChargingViewData = .init(),
        rawDataDetail: BatteryHealthRawDataViewData = .init(),
        isMonitoring: Bool = false,
        monitorError: String? = nil
    ) {
        self.overview = overview
        self.cellsDetail = cellsDetail
        self.thermalDetail = thermalDetail
        self.chargingDetail = chargingDetail
        self.rawDataDetail = rawDataDetail
        self.isMonitoring = isMonitoring
        self.monitorError = monitorError
    }
}
