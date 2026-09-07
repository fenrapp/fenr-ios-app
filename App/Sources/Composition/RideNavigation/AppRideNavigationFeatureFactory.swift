import AVFoundation
import EnvironmentDomain
import Foundation
import RideNavigation
import RideNavigationAppleMaps
import RideNavigationData
import RideNavigationDomain
import SettingsDomain
import UIKit
import VehicleSession

@MainActor
struct AppRideNavigationFeatureFactory: RideNavigationFeatureBuilding {
    let vehicleSession: any VehicleSessionService
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let settingsRepository: any AppSettingsRepository
    var routeDirectory: URL?
    var isDemo = false

    func makeFeature() -> RideNavigationFeatureModel {
        let repository = Self.makeRecordedRouteRepository(directory: routeDirectory)
        let iso8601 = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let mapPresentationMapper = RideNavigationMapPresentationMapper()
        let trailGuidance = RideNavigationTrailGuidanceController(
            planner: DefaultRideRouteGuidancePlanner(entryClassifier: RideRouteEntryClassifier()),
            projectionSelector: RideRouteProjectionSelector()
        )
        let timing = RideNavigationTiming.live
        let library = RideNavigationLibraryController(
            routeLibrary: Self.makeRouteLibrary(repository: repository, dateFormat: iso8601, isDemo: isDemo),
            timing: timing
        )
        return RideNavigationFeatureModel(
            viewModel: RideNavigationViewModel(
                dependencies: RideNavigationViewModelDependencies(
                    vehicleSession: vehicleSession,
                    observeDeviceSpeed: observeDeviceSpeed,
                    trailGuidance: trailGuidance,
                    trailMapPreparer: RideNavigationTrailMapPreparer(mapper: mapPresentationMapper),
                    trailMap: RideNavigationTrailMapController(),
                    guidance: AppleNavigationGuidanceClient(
                        synthesizer: AVSpeechSynthesizer(),
                        notificationGenerator: UINotificationFeedbackGenerator()
                    ),
                    loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
                    observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
                    updateSettings: UpdateAppSettingsUseCase(repository: settingsRepository),
                    presentationMapper: RideNavigationPresentationMapper(locale: .autoupdatingCurrent),
                    mapPresentationMapper: mapPresentationMapper,
                    mapSceneBuilder: RideNavigationMapSceneBuilder(mapper: mapPresentationMapper),
                    locationGeometry: RideNavigationLocationGeometry(),
                    timing: timing
                ),
                library: library,
                planningController: Self.makePlanningController(timing: timing),
                recorder: RideRouteRecorder(),
                breadcrumbRecorder: RideRouteRecorder()
            ),
            mapSurfaceFactory: AppleNavigationMapSurfaceFactory().makeFactory()
        )
    }

    private static func makePlanningController(timing: RideNavigationTiming) -> RideNavigationPlanningController {
        let placeSearch = ApplePlaceSearchService()
        let roadRouteCalculator = AppleRoadRouteCalculator()
        let mapLinkSecurityPolicy = AppleMapLinkSecurityPolicy.standard
        let redirectSession = makeRedirectSession(policy: mapLinkSecurityPolicy)
        return RideNavigationPlanningController(
            planning: RideNavigationPlanningService(
                roadRouteCalculator: roadRouteCalculator,
                externalMapLinkResolver: AppleExternalMapLinkResolver(
                    redirectResolver: URLSessionMapLinkRedirectResolver(ownedSession: redirectSession),
                    placeSearch: placeSearch,
                    securityPolicy: mapLinkSecurityPolicy
                ),
                trailExitFinder: AppleTrailExitFinder(
                    candidateSearch: AppleTrailExitCandidateSearch(),
                    roadRouteCalculator: roadRouteCalculator
                )
            ),
            search: RideNavigationSearchService(placeSearch: placeSearch, sleep: timing.sleep),
            timing: timing
        )
    }

    nonisolated private static func makeRouteLibrary(
        repository: FileRecordedRouteRepository,
        dateFormat: Date.ISO8601FormatStyle,
        isDemo: Bool
    ) -> RideNavigationRouteLibraryService {
        RideNavigationRouteLibraryService(
            repository: repository,
            importer: GPXRouteParser(
                now: Date.init,
                dateFormat: dateFormat,
                fallbackDateFormat: Date.ISO8601FormatStyle(),
                limits: GPXRouteImportLimits(
                    maximumFileSizeBytes: Constants.maximumGPXFileSizeBytes,
                    maximumPointCount: Constants.maximumGPXPointCount
                )
            ),
            exporter: GPXRouteExporter(dateFormat: dateFormat, isDemo: isDemo)
        )
    }

    nonisolated private static func makeRecordedRouteRepository(directory: URL?) -> FileRecordedRouteRepository {
        let fileManager = FileManager()
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return FileRecordedRouteRepository(
            fileManager: fileManager,
            directoryURL: directory ?? base.appendingPathComponent("RideNavigation", isDirectory: true),
            codec: StoredRideRouteCodec()
        )
    }

    nonisolated private static func makeRedirectSession(
        policy: AppleMapLinkSecurityPolicy
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = Constants.mapLinkTimeoutSeconds
        configuration.timeoutIntervalForResource = Constants.mapLinkTimeoutSeconds
        return URLSession(
            configuration: configuration,
            delegate: AllowedMapLinkRedirectDelegate(policy: policy),
            delegateQueue: nil
        )
    }

    private enum Constants {
        static let mapLinkTimeoutSeconds: TimeInterval = 5
        static let maximumGPXFileSizeBytes = 25 * 1_024 * 1_024
        static let maximumGPXPointCount = 100_000
    }
}
