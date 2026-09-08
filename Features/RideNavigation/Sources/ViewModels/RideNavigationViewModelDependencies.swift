import EnvironmentDomain
import RideNavigationDomain
import SettingsDomain
import VehicleSession

public struct RideNavigationViewModelDependencies: Sendable {
    let vehicleSession: any VehicleSessionService
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let loadSettings: LoadAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let updateSettings: UpdateAppSettingsUseCase
    let presentationMapper: RideNavigationPresentationMapper
    let mapPresentationMapper: RideNavigationMapPresentationMapper
    let mapSceneBuilder: RideNavigationMapSceneBuilder
    let locationGeometry: RideNavigationLocationGeometry
    let timing: RideNavigationTiming

    public init(
        vehicleSession: any VehicleSessionService,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        loadSettings: LoadAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        updateSettings: UpdateAppSettingsUseCase,
        presentationMapper: RideNavigationPresentationMapper,
        mapPresentationMapper: RideNavigationMapPresentationMapper,
        mapSceneBuilder: RideNavigationMapSceneBuilder,
        locationGeometry: RideNavigationLocationGeometry,
        timing: RideNavigationTiming
    ) {
        self.vehicleSession = vehicleSession
        self.observeDeviceSpeed = observeDeviceSpeed
        self.loadSettings = loadSettings
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.presentationMapper = presentationMapper
        self.mapPresentationMapper = mapPresentationMapper
        self.mapSceneBuilder = mapSceneBuilder
        self.locationGeometry = locationGeometry
        self.timing = timing
    }
}
