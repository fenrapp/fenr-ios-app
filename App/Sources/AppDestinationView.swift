import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeLockSettings
import BikeOnboarding
import DashboardCardSettings
import MaintenanceLog
import PowerModeSettings
import RideHistory
import SwiftUI

struct AppDestinationView: View {
    @Environment(\.openURL) private var openURL
    let route: AppRoute
    let activeSurfaces: Set<AppNavigationSurface>
    let featureStore: AppFeatureStore
    let settingsAccessory: () -> AnyView
    let onIntent: (AppNavigationIntent) -> Void
    let onChangeBike: () -> Void

    @ViewBuilder
    var body: some View {
        switch route {
        case .settings(let destination):
            AppSettingsScene(
                destination: destination,
                viewModel: featureStore.appSettingsViewModel,
                bikeLockModeTitle: bikeLockModeTitle,
                isPresentationActive: activeSurfaces.contains(.settings),
                onNavigation: handleSettingsEvent,
                accessory: settingsAccessory
            )
        case .dashboardCards(let destination):
            DashboardCardSettingsScene(
                destination: destination,
                viewModel: featureStore.dashboardCardSettingsViewModel,
                isPresentationActive: activeSurfaces.contains(.dashboardCards),
                onNavigation: handleDashboardCardsEvent
            )
        case .rideHistory(let destination):
            RideHistoryScene(
                destination: destination,
                viewModel: featureStore.rideHistoryViewModel,
                isPresentationActive: activeSurfaces.contains(.rideHistory),
                onNavigation: handleRideHistoryEvent
            )
        case .maintenance(let destination):
            MaintenanceScene(
                destination: destination,
                viewModel: featureStore.maintenanceViewModel,
                isPresentationActive: activeSurfaces.contains(.maintenance),
                onNavigation: handleMaintenanceEvent
            )
        case .diagnostics(let destination):
            BikeDiagnosticsScene(
                destination: destination,
                viewModel: featureStore.diagnosticsViewModel,
                isPresentationActive: activeSurfaces.contains(.diagnostics),
                onNavigation: handleDiagnosticsEvent
            )
        case .batteryHealth(let destination):
            BatteryHealthScene(
                destination: destination,
                viewModel: featureStore.batteryHealthViewModel,
                isPresentationActive: activeSurfaces.contains(.batteryHealth),
                onNavigation: handleBatteryHealthEvent
            )
        case .powerModes:
            PowerModeSettingsView(
                viewModel: featureStore.powerModeSettingsViewModel,
                isPresentationActive: activeSurfaces.contains(.powerModes)
            )
        case .bikeLockSettings:
            BikeLockSettingsView(viewModel: featureStore.bikeLockSettingsViewModel)
        }
    }

    private var bikeLockModeTitle: String? {
        let state = featureStore.bikeLockSettingsViewModel.viewState
        return state.isAvailable ? state.currentModeTitle : nil
    }

    private func handleSettingsEvent(_ event: AppSettingsNavigationEvent) {
        if event == .changeBike {
            onChangeBike()
        } else if let url = AppNavigationEventAdapter.externalURL(for: event) {
            openURL(url)
        } else if let intent = AppNavigationEventAdapter.intent(for: event) {
            onIntent(intent)
        }
    }

    private func handleDashboardCardsEvent(_ event: DashboardCardSettingsNavigationEvent) {
        onIntent(AppNavigationEventAdapter.intent(for: event))
    }

    private func handleRideHistoryEvent(_ event: RideHistoryNavigationEvent) {
        onIntent(AppNavigationEventAdapter.intent(for: event))
    }

    private func handleMaintenanceEvent(_ event: MaintenanceNavigationEvent) {
        onIntent(AppNavigationEventAdapter.intent(for: event))
    }

    private func handleDiagnosticsEvent(_ event: BikeDiagnosticsNavigationEvent) {
        onIntent(AppNavigationEventAdapter.intent(for: event))
    }

    private func handleBatteryHealthEvent(_ event: BatteryHealthNavigationEvent) {
        onIntent(AppNavigationEventAdapter.intent(for: event))
    }
}

struct AppOnboardingHost: View {
    let featureStore: AppFeatureStore
    var onExploreDemo: (() -> Void)?

    var body: some View {
        BikeOnboardingView(viewModel: featureStore.onboardingViewModel, onExploreDemo: onExploreDemo)
    }
}
