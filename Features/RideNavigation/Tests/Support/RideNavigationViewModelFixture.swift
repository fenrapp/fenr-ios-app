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
        self.vehicleSession = vehicleSession
        self.deviceSpeedRepository = deviceSpeedRepository
        self.placeSearch = placeSearch
        self.roadRouteCalculator = roadRouteCalculator
        self.settingsRepository = settingsRepository
        self.guidance = guidance
        viewModel = RideNavigationViewModel(
            dependencies: RideNavigationViewModelDependencies(
                vehicleSession: vehicleSession,
                observeDeviceSpeed: ObserveDeviceSpeedUseCase(repository: deviceSpeedRepository),
                routeLibrary: RideNavigationRouteLibraryService(
                    repository: repository ?? StubRecordedRouteRepository(routes: routes),
                    importer: StubGPXRouteImporter(),
                    exporter: StubGPXRouteExporter()
                ),
                planning: RideNavigationPlanningService(
                    placeSearch: placeSearch,
                    roadRouteCalculator: roadRouteCalculator,
                    externalMapLinkResolver: externalMapLinkResolver,
                    trailExitFinder: trailExitFinder
                ),
                guidance: guidance,
                loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
                saveSettings: SaveAppSettingsUseCase(repository: settingsRepository),
                presentationMapper: RideNavigationPresentationMapper(locale: Locale(identifier: "en_US")),
                mapPresentationMapper: RideNavigationMapPresentationMapper(),
                timing: timing
            ),
            recorder: RideRouteRecorder(),
            breadcrumbRecorder: RideRouteRecorder()
        )
    }
}
