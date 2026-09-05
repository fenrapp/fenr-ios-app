public enum AppSettingsDestination: Hashable, Sendable {
    case overview
    case rideDisplay
    case navigation
    case navigationAppearance
    case bikeModel
    case liveActivities
}

public enum AppSettingsNavigationEvent: Equatable, Sendable {
    case show(AppSettingsDestination)
    case openDashboardCards
    case openPowerModes
    case openRideHistory
    case openMaintenance
    case openBikeLock
    case openDiagnostics
    case changeBike
}
