public struct StarkChargerPayload: StarkPayload {
    public let requestedCurrentAmperes: Double
    public let reportedCurrentAmperes: Double
    public let targetCellVoltageVolts: Double
    public let maximumCurrentAmperes: Double
    public let maximumPowerWatts: Double
    public let maximumStateOfChargePercent: Int
    public let requestedVoltageRaw: Int
    public let reportedVoltageRaw: Int
    public let statusRaw: Int
    public let isEnabled: Bool
    public let typeRaw: Int

    public init(
        requestedCurrentAmperes: Double,
        reportedCurrentAmperes: Double,
        targetCellVoltageVolts: Double,
        maximumCurrentAmperes: Double,
        maximumPowerWatts: Double,
        maximumStateOfChargePercent: Int,
        requestedVoltageRaw: Int,
        reportedVoltageRaw: Int,
        statusRaw: Int,
        isEnabled: Bool,
        typeRaw: Int
    ) {
        self.requestedCurrentAmperes = requestedCurrentAmperes
        self.reportedCurrentAmperes = reportedCurrentAmperes
        self.targetCellVoltageVolts = targetCellVoltageVolts
        self.maximumCurrentAmperes = maximumCurrentAmperes
        self.maximumPowerWatts = maximumPowerWatts
        self.maximumStateOfChargePercent = maximumStateOfChargePercent
        self.requestedVoltageRaw = requestedVoltageRaw
        self.reportedVoltageRaw = reportedVoltageRaw
        self.statusRaw = statusRaw
        self.isEnabled = isEnabled
        self.typeRaw = typeRaw
    }
}
