import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeLockSettings
import BikeOnboarding
import ChargingSettings
import DashboardCardSettings
import MaintenanceLog
import PowerModeSettings
import RideDashboard
import RideHistory
import RideNavigation

@MainActor
struct AppFeatureStore {
    let chargingSettingsViewModel: ChargingSettingsViewModel?
    let diagnosticsViewModel: BikeDiagnosticsViewModel
    let batteryHealthViewModel: BatteryHealthViewModel
    let bikeLockSettingsViewModel: BikeLockSettingsViewModel
    let onboardingViewModel: BikeOnboardingViewModel
    let appSettingsViewModel: AppSettingsViewModel
    let dashboardCardSettingsViewModel: DashboardCardSettingsViewModel
    let powerModes: PowerModeFeature
    var powerModeSettingsViewModel: PowerModeSettingsViewModel { powerModes.basic }
    var advancedPowerModeViewModel: PowerModeAdvancedViewModel { powerModes.advanced }
    let rideHistoryViewModel: RideHistoryViewModel
    let maintenanceViewModel: MaintenanceViewModel
    let rideDashboardFactory: any RideDashboardFeatureBuilding
    let offlineMaps: AppOfflineMapsFeature
    let offlineMapsFactory: OfflineMapsFeatureFactory
    let rideNavigationFactory: any RideNavigationFeatureBuilding
}
