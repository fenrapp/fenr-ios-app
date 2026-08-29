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
        trailExitFinder: any TrailExitFinding = StubTrailExitFinder()
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
            vehicleSession: vehicleSession,
            observeDeviceSpeed: ObserveDeviceSpeedUseCase(repository: deviceSpeedRepository),
            repository: repository ?? StubRecordedRouteRepository(routes: routes),
            importer: StubGPXRouteImporter(),
            exporter: StubGPXRouteExporter(),
            placeSearch: placeSearch,
            roadRouteCalculator: roadRouteCalculator,
            externalMapLinkResolver: StubExternalMapLinkResolver(),
            trailExitFinder: trailExitFinder,
            guidance: guidance,
            loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
            saveSettings: SaveAppSettingsUseCase(repository: settingsRepository),
            mapper: RideNavigationPresentationMapper(locale: Locale(identifier: "en_US")),
            recorder: RideRouteRecorder(),
            breadcrumbRecorder: RideRouteRecorder(),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
    }
}
