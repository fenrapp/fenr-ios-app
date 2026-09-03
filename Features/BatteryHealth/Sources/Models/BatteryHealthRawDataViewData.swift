public struct BatteryHealthRawDataViewData: Equatable, Sendable {
    public let datasets: [BatteryHealthDatasetViewData]
    public let rawFlags: [BatteryHealthMetricViewData]
    public let chargeAuditLines: [String]

    public init(
        datasets: [BatteryHealthDatasetViewData] = [],
        rawFlags: [BatteryHealthMetricViewData] = [],
        chargeAuditLines: [String] = []
    ) {
        self.datasets = datasets
        self.rawFlags = rawFlags
        self.chargeAuditLines = chargeAuditLines
    }
}
