@MainActor
public struct RideDashboardCardLifecycleDependencies {
    public let currentTrip: CurrentTripCardViewModel
    public let statistics: TripStatisticsCardViewModel
    public let efficiency: EfficiencyCardViewModel
    public let range: RangeCardViewModel
    public let systemHealth: SystemHealthCardViewModel
    public let dynamics: RideDynamicsCardViewModel
    public let charging: ChargingDashboardViewModel
    public let bikeLock: BikeLockCardViewModel

    public init(
        currentTrip: CurrentTripCardViewModel,
        statistics: TripStatisticsCardViewModel,
        efficiency: EfficiencyCardViewModel,
        range: RangeCardViewModel,
        systemHealth: SystemHealthCardViewModel,
        dynamics: RideDynamicsCardViewModel,
        charging: ChargingDashboardViewModel,
        bikeLock: BikeLockCardViewModel
    ) {
        self.currentTrip = currentTrip
        self.statistics = statistics
        self.efficiency = efficiency
        self.range = range
        self.systemHealth = systemHealth
        self.dynamics = dynamics
        self.charging = charging
        self.bikeLock = bikeLock
    }
}
