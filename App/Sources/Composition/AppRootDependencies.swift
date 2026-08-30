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
import RideNavigationDomain

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
    let incomingMapLinkStore: any IncomingMapLinkStoring
    let setupFlow: BikeSetupFlowController
    let lifecycleController: AppLifecycleController
    let interfaceOrientationController: InterfaceOrientationController
}
