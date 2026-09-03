import AppSettings
import BatteryHealth
import BikeDiagnostics
import DashboardCardSettings
import Foundation
import RideHistory

enum AppRoute: Hashable {
    case settings(AppSettingsDestination)
    case dashboardCards(DashboardCardSettingsDestination)
    case rideHistory(RideHistoryDestination)
    case diagnostics(BikeDiagnosticsDestination)
    case batteryHealth(BatteryHealthDestination)
    case powerModes
    case bikeLockSettings

    var family: AppNavigationSurface {
        switch self {
        case .settings: .settings
        case .dashboardCards: .dashboardCards
        case .rideHistory: .rideHistory
        case .diagnostics: .diagnostics
        case .batteryHealth: .batteryHealth
        case .powerModes: .powerModes
        case .bikeLockSettings: .bikeLockSettings
        }
    }

    var canonicalParent: AppRoute? {
        switch self {
        case .settings(.overview),
             .dashboardCards(.overview),
             .rideHistory(.overview),
             .diagnostics(.overview),
             .batteryHealth(.overview),
             .powerModes,
             .bikeLockSettings:
            nil
        case .settings:
            .settings(.overview)
        case .dashboardCards:
            .dashboardCards(.overview)
        case .rideHistory:
            .rideHistory(.overview)
        case .diagnostics:
            .diagnostics(.overview)
        case .batteryHealth:
            .batteryHealth(.overview)
        }
    }
}
