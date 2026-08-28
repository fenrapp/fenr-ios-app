import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeOnboarding
import PowerModeSettings
import RideDashboard
import RideHistory

@MainActor
struct AppRootDependencies {
    let diagnosticsViewModel: BikeDiagnosticsViewModel
    let batteryHealthViewModel: BatteryHealthViewModel
    let rideDashboardFactory: any RideDashboardFeatureBuilding
    let onboardingViewModel: BikeOnboardingViewModel
    let appSettingsViewModel: AppSettingsViewModel
    let powerModeSettingsViewModel: PowerModeSettingsViewModel
    let rideHistoryViewModel: RideHistoryViewModel
    let setupFlow: BikeSetupFlowController
    let lifecycleController: AppLifecycleController
    let interfaceOrientationController: InterfaceOrientationController
}
