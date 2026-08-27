import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeOnboarding
import RideDashboard

@MainActor
struct AppRootDependencies {
    let diagnosticsViewModel: BikeDiagnosticsViewModel
    let batteryHealthViewModel: BatteryHealthViewModel
    let rideDashboardFactory: any RideDashboardFeatureBuilding
    let onboardingViewModel: BikeOnboardingViewModel
    let appSettingsViewModel: AppSettingsViewModel
    let setupFlow: BikeSetupFlowController
    let lifecycleController: AppLifecycleController
    let interfaceOrientationController: InterfaceOrientationController
}
