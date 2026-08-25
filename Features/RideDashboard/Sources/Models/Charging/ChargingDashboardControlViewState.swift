public struct ChargingDashboardControlViewState: Equatable, Sendable {
    public let isEnabled: Bool
    public let power: ChargingDashboardAdjustmentViewState
    public let target: ChargingDashboardAdjustmentViewState
    public let status: ChargingDashboardStatusViewData?

    public init(
        isEnabled: Bool = false,
        power: ChargingDashboardAdjustmentViewState = .init(
            selected: 300,
            minimum: 300,
            maximum: 3_300,
            step: 100
        ),
        target: ChargingDashboardAdjustmentViewState = .init(
            selected: 100,
            minimum: 1,
            maximum: 100,
            step: 1
        ),
        status: ChargingDashboardStatusViewData? = nil
    ) {
        self.isEnabled = isEnabled
        self.power = power
        self.target = target
        self.status = status
    }
}
