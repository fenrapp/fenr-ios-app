public struct ChargingDashboardViewState: Equatable, Sendable {
    public var batteryPercent: Int?
    public var maximumPower: RideDashboardMeasurement?
    public var reportedCurrent: RideDashboardMeasurement?
    public var batteryTemperature: RideDashboardMeasurement?
    public var targetStateOfChargePercent: Int?
    public var estimatedTimeRemaining: String?
    public var isHighBeamOn: Bool
    public var isLeftBlinkerOn: Bool
    public var isBrakeActive: Bool
    public var isRightBlinkerOn: Bool
    public var isFaultActive: Bool

    public init(
        batteryPercent: Int? = nil,
        maximumPower: RideDashboardMeasurement? = nil,
        reportedCurrent: RideDashboardMeasurement? = nil,
        batteryTemperature: RideDashboardMeasurement? = nil,
        targetStateOfChargePercent: Int? = nil,
        estimatedTimeRemaining: String? = nil,
        isHighBeamOn: Bool = false,
        isLeftBlinkerOn: Bool = false,
        isBrakeActive: Bool = false,
        isRightBlinkerOn: Bool = false,
        isFaultActive: Bool = false
    ) {
        self.batteryPercent = batteryPercent
        self.maximumPower = maximumPower
        self.reportedCurrent = reportedCurrent
        self.batteryTemperature = batteryTemperature
        self.targetStateOfChargePercent = targetStateOfChargePercent
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.isHighBeamOn = isHighBeamOn
        self.isLeftBlinkerOn = isLeftBlinkerOn
        self.isBrakeActive = isBrakeActive
        self.isRightBlinkerOn = isRightBlinkerOn
        self.isFaultActive = isFaultActive
    }
}
