import EnvironmentDomain
import RideNavigationDomain
import SettingsDomain
import VehicleSession

public struct RideNavigationViewModelDependencies: Sendable {
    let vehicleSession: any VehicleSessionService
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let routeLibrary: RideNavigationRouteLibraryService
    let planning: RideNavigationPlanningService
    let trailGuidance: RideNavigationTrailGuidanceController
    let trailMapPreparer: any RideNavigationTrailMapPreparing
    let trailMap: RideNavigationTrailMapController
    let guidance: any NavigationGuidanceClient
    let loadSettings: LoadAppSettingsUseCase
    let saveSettings: SaveAppSettingsUseCase
    let presentationMapper: RideNavigationPresentationMapper
    let mapPresentationMapper: RideNavigationMapPresentationMapper
    let timing: RideNavigationTiming

    public init(
        vehicleSession: any VehicleSessionService,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        routeLibrary: RideNavigationRouteLibraryService,
        planning: RideNavigationPlanningService,
        trailGuidance: RideNavigationTrailGuidanceController,
        trailMapPreparer: any RideNavigationTrailMapPreparing,
        trailMap: RideNavigationTrailMapController,
        guidance: any NavigationGuidanceClient,
        loadSettings: LoadAppSettingsUseCase,
        saveSettings: SaveAppSettingsUseCase,
        presentationMapper: RideNavigationPresentationMapper,
        mapPresentationMapper: RideNavigationMapPresentationMapper,
        timing: RideNavigationTiming
    ) {
        self.vehicleSession = vehicleSession
        self.observeDeviceSpeed = observeDeviceSpeed
        self.routeLibrary = routeLibrary
        self.planning = planning
        self.trailGuidance = trailGuidance
        self.trailMapPreparer = trailMapPreparer
        self.trailMap = trailMap
        self.guidance = guidance
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.presentationMapper = presentationMapper
        self.mapPresentationMapper = mapPresentationMapper
        self.timing = timing
    }
}
