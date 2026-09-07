import EnvironmentDomain
import RideNavigation
import SettingsDomain
import VehicleSession

@MainActor
struct AppRideNavigationFactoryContext {
    let vehicleSession: any VehicleSessionService
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let settingsRepository: any AppSettingsRepository

    func makeFactory(
        builder: AppRideNavigationFactoryBuilder?,
        options: AppExperienceOptions
    ) -> any RideNavigationFeatureBuilding {
        builder?(self) ?? AppRideNavigationFeatureFactory(
            vehicleSession: vehicleSession,
            observeDeviceSpeed: observeDeviceSpeed,
            settingsRepository: settingsRepository,
            routeDirectory: options.routeDirectory,
            isDemo: options.isDemo
        )
    }
}

typealias AppRideNavigationFactoryBuilder = @MainActor (
    AppRideNavigationFactoryContext
) -> any RideNavigationFeatureBuilding
