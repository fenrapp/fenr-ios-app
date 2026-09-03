import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeLockSettings
import BikeOnboarding
import Combine
import DashboardCardSettings
import PowerModeSettings
import RideDashboard
import RideHistory
import RideNavigation

@MainActor
final class AppFeatureStore: ObservableObject {
    let diagnosticsViewModel: BikeDiagnosticsViewModel
    let batteryHealthViewModel: BatteryHealthViewModel
    let bikeLockSettingsViewModel: BikeLockSettingsViewModel
    let onboardingViewModel: BikeOnboardingViewModel
    let appSettingsViewModel: AppSettingsViewModel
    let dashboardCardSettingsViewModel: DashboardCardSettingsViewModel
    let powerModeSettingsViewModel: PowerModeSettingsViewModel
    let rideHistoryViewModel: RideHistoryViewModel
    let rideDashboardFactory: any RideDashboardFeatureBuilding
    let rideNavigationFactory: any RideNavigationFeatureBuilding

    init(
        diagnosticsViewModel: BikeDiagnosticsViewModel,
        batteryHealthViewModel: BatteryHealthViewModel,
        bikeLockSettingsViewModel: BikeLockSettingsViewModel,
        onboardingViewModel: BikeOnboardingViewModel,
        appSettingsViewModel: AppSettingsViewModel,
        dashboardCardSettingsViewModel: DashboardCardSettingsViewModel,
        powerModeSettingsViewModel: PowerModeSettingsViewModel,
        rideHistoryViewModel: RideHistoryViewModel,
        rideDashboardFactory: any RideDashboardFeatureBuilding,
        rideNavigationFactory: any RideNavigationFeatureBuilding
    ) {
        self.diagnosticsViewModel = diagnosticsViewModel
        self.batteryHealthViewModel = batteryHealthViewModel
        self.bikeLockSettingsViewModel = bikeLockSettingsViewModel
        self.onboardingViewModel = onboardingViewModel
        self.appSettingsViewModel = appSettingsViewModel
        self.dashboardCardSettingsViewModel = dashboardCardSettingsViewModel
        self.powerModeSettingsViewModel = powerModeSettingsViewModel
        self.rideHistoryViewModel = rideHistoryViewModel
        self.rideDashboardFactory = rideDashboardFactory
        self.rideNavigationFactory = rideNavigationFactory
    }
}
