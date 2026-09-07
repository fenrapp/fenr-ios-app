import Foundation
import RideNavigation
import RideNavigationAppleMaps
import RideNavigationDomain
import SettingsDomain

@MainActor
struct DebugNavigationFeatureFactory: RideNavigationFeatureBuilding {
    let context: AppRideNavigationFactoryContext
    let routeLibrary: RideNavigationRouteLibraryService
    let planningService: DebugNavigationPlanningService
    let timing: RideNavigationTiming

    func makeFeature() -> RideNavigationFeatureModel {
        let mapper = RideNavigationMapPresentationMapper()
        let geometry = RideNavigationLocationGeometry()
        let library = RideNavigationLibraryController(routeLibrary: routeLibrary, timing: timing)
        let planning = RideNavigationPlanningController(
            planning: .init(
                roadRouteCalculator: planningService,
                externalMapLinkResolver: planningService,
                trailExitFinder: planningService
            ),
            search: .init(placeSearch: planningService, sleep: timing.sleep),
            timing: timing
        )
        let activity = RideNavigationActivityController(
            dependencies: .init(
                library: library,
                planning: planning,
                trailGuidance: RideNavigationTrailGuidanceController(
                    planner: DefaultRideRouteGuidancePlanner(entryClassifier: RideRouteEntryClassifier()),
                    projectionSelector: RideRouteProjectionSelector()
                ),
                trailMapPreparer: RideNavigationTrailMapPreparer(mapper: mapper),
                trailMap: RideNavigationTrailMapController(),
                guidance: DebugNavigationGuidanceClient(),
                locationGeometry: geometry,
                timing: timing
            ),
            recorder: RideRouteRecorder(),
            breadcrumbRecorder: RideRouteRecorder()
        )
        return RideNavigationFeatureModel(
            viewModel: RideNavigationViewModel(
                dependencies: .init(
                    vehicleSession: context.vehicleSession,
                    observeDeviceSpeed: context.observeDeviceSpeed,
                    loadSettings: LoadAppSettingsUseCase(repository: context.settingsRepository),
                    observeSettings: ObserveAppSettingsUseCase(repository: context.settingsRepository),
                    updateSettings: UpdateAppSettingsUseCase(repository: context.settingsRepository),
                    presentationMapper: RideNavigationPresentationMapper(locale: Locale(identifier: "en_US")),
                    mapPresentationMapper: mapper,
                    mapSceneBuilder: RideNavigationMapSceneBuilder(mapper: mapper),
                    locationGeometry: geometry,
                    timing: timing
                ),
                library: library,
                planningController: planning,
                activityController: activity
            ),
            mapSurfaceFactory: AppleNavigationMapSurfaceFactory().makeFactory()
        )
    }
}
