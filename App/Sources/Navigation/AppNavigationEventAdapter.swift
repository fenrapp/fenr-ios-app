import AppSettings
import BatteryHealth
import BikeDiagnostics
import DashboardCardSettings
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

    static func intent(for event: AppSettingsNavigationEvent) -> AppNavigationIntent {
        switch event {
        case .show(let destination): .push(.settings(destination))
        case .openDashboardCards: .push(.dashboardCards(.overview))
        case .openPowerModes: .push(.powerModes)
        case .openRideHistory: .push(.rideHistory(.overview))
        case .openMaintenance: .push(.maintenance(.overview))
        case .openBikeLock: .push(.bikeLockSettings)
        case .openDiagnostics: .push(.diagnostics(.overview))
        case .changeBike: .popToRoot
        }
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
