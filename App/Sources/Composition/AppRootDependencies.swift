import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeLockSettings
import BikeOnboarding
import DashboardCardSettings
import PowerModeSettings
import RideDashboard
import RideHistory
import RideNavigation

@MainActor
struct AppRootDependencies {
    let diagnosticsViewModel: BikeDiagnosticsViewModel
    let batteryHealthViewModel: BatteryHealthViewModel
    let bikeLockSettingsViewModel: BikeLockSettingsViewModel
    let rideDashboardFactory: any RideDashboardFeatureBuilding
    let onboardingViewModel: BikeOnboardingViewModel
    let appSettingsViewModel: AppSettingsViewModel
    let dashboardCardSettingsViewModel: DashboardCardSettingsViewModel
    let powerModeSettingsViewModel: PowerModeSettingsViewModel
    let rideHistoryViewModel: RideHistoryViewModel
    let rideNavigationFactory: any RideNavigationFeatureBuilding
    let setupFlow: BikeSetupFlowController
    let router: AppRootRouter
    let lifecycleController: AppLifecycleController
}
