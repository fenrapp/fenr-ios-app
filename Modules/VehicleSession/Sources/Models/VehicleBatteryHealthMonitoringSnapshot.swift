import BikeDomain

public struct VehicleBatteryHealthMonitoringSnapshot: Equatable, Sendable {
    public let health: BikeBatteryHealth
    public let state: VehicleBatteryHealthMonitoringState
    public let revision: Int

    public init(
        health: BikeBatteryHealth = .init(),
        state: VehicleBatteryHealthMonitoringState = .inactive,
        revision: Int = 0
    ) {
        self.health = health
        self.state = state
        self.revision = revision
    }
}
