public enum AppSettingsDestination: Hashable, Sendable {
    case overview
    case rideDisplay
    case bikeModel
}

public enum AppSettingsNavigationEvent: Equatable, Sendable {
    case show(AppSettingsDestination)
    case openDashboardCards
    case openPowerModes
    case openRideHistory
    case openBikeLock
    case openDiagnostics
}
