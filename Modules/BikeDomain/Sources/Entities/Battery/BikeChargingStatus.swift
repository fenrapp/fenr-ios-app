public struct BikeChargingStatus: Equatable, Sendable {
    public let requestedCurrentAmperes: Double
    public let reportedCurrentAmperes: Double
    public let maximumCurrentAmperes: Double
    public let maximumPowerWatts: Double
    public let targetCellVoltageVolts: Double
    public let maximumStateOfChargePercent: Int

    public init(
        requestedCurrentAmperes: Double,
        reportedCurrentAmperes: Double,
        maximumCurrentAmperes: Double,
        maximumPowerWatts: Double,
        targetCellVoltageVolts: Double,
        maximumStateOfChargePercent: Int
    ) {
        self.requestedCurrentAmperes = requestedCurrentAmperes
        self.reportedCurrentAmperes = reportedCurrentAmperes
        self.maximumCurrentAmperes = maximumCurrentAmperes
        self.maximumPowerWatts = maximumPowerWatts
        self.targetCellVoltageVolts = targetCellVoltageVolts
        self.maximumStateOfChargePercent = maximumStateOfChargePercent
    }
}
