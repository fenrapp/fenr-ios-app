import EnvironmentDomain
import RideNavigationDomain
import SettingsDomain
import VehicleSession

public struct RideNavigationViewModelDependencies: Sendable {
    let vehicleSession: any VehicleSessionService
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let planning: RideNavigationPlanningService
    let trailGuidance: RideNavigationTrailGuidanceController
    let trailMapPreparer: any RideNavigationTrailMapPreparing
    let trailMap: RideNavigationTrailMapController
    let guidance: any NavigationGuidanceClient
    let loadSettings: LoadAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let updateSettings: UpdateAppSettingsUseCase
    let presentationMapper: RideNavigationPresentationMapper
    let mapPresentationMapper: RideNavigationMapPresentationMapper
    let mapSceneBuilder: RideNavigationMapSceneBuilder
    let searchService: RideNavigationSearchService
    let locationGeometry: RideNavigationLocationGeometry
    let timing: RideNavigationTiming

    public init(
        vehicleSession: any VehicleSessionService,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        planning: RideNavigationPlanningService,
        trailGuidance: RideNavigationTrailGuidanceController,
        trailMapPreparer: any RideNavigationTrailMapPreparing,
        trailMap: RideNavigationTrailMapController,
        guidance: any NavigationGuidanceClient,
        loadSettings: LoadAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        updateSettings: UpdateAppSettingsUseCase,
        presentationMapper: RideNavigationPresentationMapper,
        mapPresentationMapper: RideNavigationMapPresentationMapper,
        mapSceneBuilder: RideNavigationMapSceneBuilder,
        searchService: RideNavigationSearchService,
        locationGeometry: RideNavigationLocationGeometry,
        timing: RideNavigationTiming
    ) {
        self.vehicleSession = vehicleSession
        self.observeDeviceSpeed = observeDeviceSpeed
        self.planning = planning
        self.trailGuidance = trailGuidance
        self.trailMapPreparer = trailMapPreparer
        self.trailMap = trailMap
        self.guidance = guidance
        self.loadSettings = loadSettings
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.presentationMapper = presentationMapper
        self.mapPresentationMapper = mapPresentationMapper
        self.mapSceneBuilder = mapSceneBuilder
        self.searchService = searchService
        self.locationGeometry = locationGeometry
        self.timing = timing
    }
}
