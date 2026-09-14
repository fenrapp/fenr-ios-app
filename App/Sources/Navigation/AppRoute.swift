import AppSettings
import BatteryHealth
import BikeDiagnostics
import DashboardCardSettings
import Foundation
import MaintenanceLog
import RideHistory

enum AppRoute: Hashable {
    case settings(AppSettingsDestination)
    case dashboardCards(DashboardCardSettingsDestination)
    case rideHistory(RideHistoryDestination)
    case maintenance(MaintenanceDestination)
    case diagnostics(BikeDiagnosticsDestination)
    case batteryHealth(BatteryHealthDestination)
    case powerModes
    case advancedPowerModes
    case chargingSettings
    case bikeLockSettings

    var family: AppNavigationSurface {
        switch self {
        case .settings, .chargingSettings: .settings
        case .dashboardCards: .dashboardCards
        case .rideHistory: .rideHistory
        case .maintenance: .maintenance
        case .diagnostics: .diagnostics
        case .batteryHealth: .batteryHealth
        case .powerModes, .advancedPowerModes: .powerModes
        case .bikeLockSettings: .bikeLockSettings
        }
    }

    var canonicalParent: AppRoute? {
        switch self {
        case .settings(.overview),
             .dashboardCards(.overview),
             .rideHistory(.overview),
             .maintenance(.overview),
             .diagnostics(.overview),
             .batteryHealth(.overview),
             .powerModes,
             .bikeLockSettings:
            nil
        case .chargingSettings:
            .settings(.overview)
        case .advancedPowerModes:
            .powerModes
        case .settings(.rideProgressBar), .settings(.rideBatteryDisplay),
             .settings(.rideInformation), .settings(.rideSpeed):
            .settings(.rideDisplay)
        case .settings:
            .settings(.overview)
        case .dashboardCards:
            .dashboardCards(.overview)
        case .rideHistory:
            .rideHistory(.overview)
        case .maintenance:
            .maintenance(.overview)
        case .diagnostics:
            .diagnostics(.overview)
        case .batteryHealth:
            .batteryHealth(.overview)
        }
    }
}
