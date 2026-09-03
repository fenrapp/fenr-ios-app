public struct BatteryHealthChargingViewData: Equatable, Sendable {
    public let metrics: [BatteryHealthMetricViewData]
    public let control: BatteryHealthChargeControlViewState

    public init(
        metrics: [BatteryHealthMetricViewData] = [],
        control: BatteryHealthChargeControlViewState = .init()
    ) {
        self.metrics = metrics
        self.control = control
    }
}
