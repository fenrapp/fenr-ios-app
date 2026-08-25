import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeOnboarding
import RideDashboard

@MainActor
struct AppRootDependencies {
    let diagnosticsViewModel: BikeDiagnosticsViewModel
    let batteryHealthViewModel: BatteryHealthViewModel
    let dashboardViewModel: RideDashboardViewModel
    let chargingDashboardViewModel: ChargingDashboardViewModel
    let onboardingViewModel: BikeOnboardingViewModel
    let appSettingsViewModel: AppSettingsViewModel
    let setupFlow: BikeSetupFlowController
    let lifecycleController: AppLifecycleController
    let interfaceOrientationController: InterfaceOrientationController
}
