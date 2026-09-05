public enum AppSettingsDestination: Hashable, Sendable {
    case overview
    case rideDisplay
    case navigation
    case navigationAppearance
    case bikeModel
    case liveActivities
    case acknowledgments
}

public enum AppSettingsNavigationEvent: Equatable, Sendable {
    case show(AppSettingsDestination)
    case openDashboardCards
    case openPowerModes
    case openRideHistory
    case openMaintenance
    case openBikeLock
    case openDiagnostics
    case openSupport
    case openPrivacyPolicy
    case openTerms
    case openAcknowledgedProject(AcknowledgedProject)
    case changeBike
}
