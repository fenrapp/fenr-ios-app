import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain

@MainActor
struct RideNavigationViewModelFixture {
    let vehicleSession: TestVehicleSessionService
    let deviceSpeedRepository: TestDeviceSpeedRepository
    let placeSearch: ControllablePlaceSearch
    let roadRouteCalculator: ControllableRoadRouteCalculator
    let settingsRepository: StubAppSettingsRepository
    let guidance: NoOpNavigationGuidanceClient
    let viewModel: RideNavigationViewModel

    init(
        routes: [RideRoute] = [],
        settings: AppSettings = .init(),
        repository: (any RecordedRouteRepository)? = nil,
        importer: any GPXRouteImporting = StubGPXRouteImporter(),
        externalMapLinkResolver: any ExternalMapLinkResolving = StubExternalMapLinkResolver(),
        trailExitFinder: any TrailExitFinding = StubTrailExitFinder(),
        timing: RideNavigationTiming = RideNavigationTiming(
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            sleep: { duration in
                if duration == .seconds(1) {
                    try await Task.sleep(for: .seconds(60))
                }
            }
        )
    ) {
        let vehicleSession = TestVehicleSessionService()
        let deviceSpeedRepository = TestDeviceSpeedRepository()
        let placeSearch = ControllablePlaceSearch()
        let roadRouteCalculator = ControllableRoadRouteCalculator()
        let settingsRepository = StubAppSettingsRepository(settings: settings)
        let guidance = NoOpNavigationGuidanceClient()
        let mapPresentationMapper = RideNavigationMapPresentationMapper()
        self.vehicleSession = vehicleSession
        self.deviceSpeedRepository = deviceSpeedRepository
        self.placeSearch = placeSearch
        self.roadRouteCalculator = roadRouteCalculator
        self.settingsRepository = settingsRepository
        self.guidance = guidance
        let routeRepository = repository ?? StubRecordedRouteRepository(routes: routes)
        viewModel = RideNavigationViewModel(
            dependencies: RideNavigationViewModelDependencies(
                vehicleSession: vehicleSession,
                observeDeviceSpeed: ObserveDeviceSpeedUseCase(repository: deviceSpeedRepository),
                planning: RideNavigationPlanningService(
                    roadRouteCalculator: roadRouteCalculator,
                    externalMapLinkResolver: externalMapLinkResolver,
                    trailExitFinder: trailExitFinder
                ),
                trailGuidance: RideNavigationTrailGuidanceController(
                    planner: DefaultRideRouteGuidancePlanner(entryClassifier: RideRouteEntryClassifier()),
                    projectionSelector: RideRouteProjectionSelector()
                ),
                trailMapPreparer: RideNavigationTrailMapPreparer(
                    mapper: mapPresentationMapper
                ),
                trailMap: RideNavigationTrailMapController(),
                guidance: guidance,
                loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
                updateSettings: UpdateAppSettingsUseCase(repository: settingsRepository),
                presentationMapper: RideNavigationPresentationMapper(locale: Locale(identifier: "en_US")),
                mapPresentationMapper: mapPresentationMapper,
                mapSceneBuilder: RideNavigationMapSceneBuilder(mapper: mapPresentationMapper),
                searchService: RideNavigationSearchService(
                    placeSearch: placeSearch,
                    sleep: timing.sleep
                ),
                locationGeometry: RideNavigationLocationGeometry(),
                timing: timing
            ),
            library: RideNavigationLibraryController(
                routeLibrary: RideNavigationRouteLibraryService(
                    repository: routeRepository,
                    importer: importer,
                    exporter: StubGPXRouteExporter()
                ),
                timing: timing
            ),
            recorder: RideRouteRecorder(),
            breadcrumbRecorder: RideRouteRecorder()
        )
    }
}
