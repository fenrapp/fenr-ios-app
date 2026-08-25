public struct ChargingDashboardGaugeViewState: Equatable, Sendable {
    public let batteryPercent: Int?
    public let targetPercent: Int?
    public let estimatedTimeRemaining: String?
    public let isBalancingAtFullCharge: Bool
    public let readout: ChargingDashboardReadoutViewData
    public let control: ChargingDashboardControlViewState

    public init(
        batteryPercent: Int? = nil,
        targetPercent: Int? = nil,
        estimatedTimeRemaining: String? = nil,
        isBalancingAtFullCharge: Bool = false,
        readout: ChargingDashboardReadoutViewData = .init(),
        control: ChargingDashboardControlViewState = .init()
    ) {
        self.batteryPercent = batteryPercent
        self.targetPercent = targetPercent
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.isBalancingAtFullCharge = isBalancingAtFullCharge
        self.readout = readout
        self.control = control
    }
}
