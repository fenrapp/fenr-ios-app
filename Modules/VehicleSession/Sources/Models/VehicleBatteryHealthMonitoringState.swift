public enum VehicleBatteryHealthMonitoringState: Equatable, Sendable {
    case inactive
    case starting
    case active
    case failed(String)
}
