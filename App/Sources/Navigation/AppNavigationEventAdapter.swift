import AppSettings
import BatteryHealth
import BikeDiagnostics
import DashboardCardSettings
import Foundation
import MaintenanceLog
import RideDashboard
import RideHistory

enum AppNavigationEventAdapter {
    static func intent(for event: RideDashboardNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .openSettings: .push(.settings(.overview))
        case .openRideNavigation: .showRideNavigation(nil)
        }
    }

    static func intent(for event: AppSettingsNavigationEvent) -> AppNavigationIntent? {
        switch event {
        case .show(let destination): .push(.settings(destination))
        case .openDashboardCards: .push(.dashboardCards(.overview))
        case .openPowerModes: .push(.powerModes)
        case .openRideHistory: .push(.rideHistory(.overview))
        case .openMaintenance: .push(.maintenance(.overview))
        case .openBikeLock: .push(.bikeLockSettings)
        case .openDiagnostics: .push(.diagnostics(.overview))
        case .openSupport, .openPrivacyPolicy, .openTerms, .openAcknowledgedProject: nil
        case .changeBike: .popToRoot
        }
    }

    static func externalURL(for event: AppSettingsNavigationEvent) -> URL? {
        switch event {
        case .openSupport: URL(string: "https://fenr.to")
        case .openPrivacyPolicy: URL(string: "https://fenr.to/privacy")
        case .openTerms: URL(string: "https://fenr.to/terms")
        case .openAcknowledgedProject(let project): projectURL(project)
        default: nil
        }
    }

    private static func projectURL(_ project: AcknowledgedProject) -> URL? {
        let address: String = switch project {
        case .svagMini: "https://github.com/b1naryth1ef/svag-mini"
        case .svagTelemetryFormat: "https://github.com/b1naryth1ef/svag-telemetry-format"
        case .starkVargGarminBridge: "https://github.com/tonysilvasa/stark-varg-garmin-bridge"
        case .boschGarminBridge: "https://github.com/Soarcer/bosch-garmin-bridge"
        case .xcodeGen: "https://github.com/yonaskolb/XcodeGen"
        case .swiftLint: "https://github.com/realm/SwiftLint"
        case .appStoreConnectCLI: "https://github.com/rorkai/App-Store-Connect-CLI"
        }
        return URL(string: address)
    }

    static func intent(for event: MaintenanceNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .show(let destination): .push(.maintenance(destination))
        case .close(let destination): .pop(ifTop: .maintenance(destination))
        }
    }

    static func intent(for event: DashboardCardSettingsNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .show(let destination): .push(.dashboardCards(destination))
        }
    }

    static func intent(for event: RideHistoryNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .show(let destination): .push(.rideHistory(destination))
        }
    }

    static func intent(for event: BikeDiagnosticsNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .show(let destination): .push(.diagnostics(destination))
        case .openBatteryHealth: .push(.batteryHealth(.overview))
        }
    }

    static func intent(for event: BatteryHealthNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .show(let destination): .push(.batteryHealth(destination))
        }
    }
}
