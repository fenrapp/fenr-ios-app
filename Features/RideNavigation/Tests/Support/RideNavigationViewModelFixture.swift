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
        let library = RideNavigationLibraryController(
            routeLibrary: RideNavigationRouteLibraryService(
                repository: routeRepository, importer: importer, exporter: StubGPXRouteExporter()
            ),
            timing: timing
        )
        let planning = RideNavigationPlanningController(
            planning: RideNavigationPlanningService(
                roadRouteCalculator: roadRouteCalculator,
                externalMapLinkResolver: externalMapLinkResolver,
                trailExitFinder: trailExitFinder
            ),
            search: RideNavigationSearchService(placeSearch: placeSearch, sleep: timing.sleep),
            timing: timing
        )
        let activity = Self.makeActivity(
            library: library, planning: planning, mapper: mapPresentationMapper,
            guidance: guidance, timing: timing
        )
        viewModel = RideNavigationViewModel(
            dependencies: RideNavigationViewModelDependencies(
                vehicleSession: vehicleSession,
                observeDeviceSpeed: ObserveDeviceSpeedUseCase(repository: deviceSpeedRepository),
                loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
                updateSettings: UpdateAppSettingsUseCase(repository: settingsRepository),
                presentationMapper: RideNavigationPresentationMapper(locale: Locale(identifier: "en_US")),
                mapPresentationMapper: mapPresentationMapper,
                mapSceneBuilder: RideNavigationMapSceneBuilder(mapper: mapPresentationMapper),
                locationGeometry: activity.dependencies.locationGeometry,
                timing: timing
            ),
            library: library,
            planningController: planning,
            activityController: activity
        )
    }

    private static func makeActivity(
        library: RideNavigationLibraryController,
        planning: RideNavigationPlanningController,
        mapper: RideNavigationMapPresentationMapper,
        guidance: NoOpNavigationGuidanceClient,
        timing: RideNavigationTiming
    ) -> RideNavigationActivityController {
        RideNavigationActivityController(
            dependencies: RideNavigationActivityDependencies(
                library: library,
                planning: planning,
                trailGuidance: RideNavigationTrailGuidanceController(
                    planner: DefaultRideRouteGuidancePlanner(entryClassifier: RideRouteEntryClassifier()),
                    projectionSelector: RideRouteProjectionSelector()
                ),
                trailMapPreparer: RideNavigationTrailMapPreparer(mapper: mapper),
                trailMap: RideNavigationTrailMapController(),
                guidance: guidance,
                locationGeometry: RideNavigationLocationGeometry(),
                timing: timing
            ),
            recorder: RideRouteRecorder(),
            breadcrumbRecorder: RideRouteRecorder()
        )
    }

}
