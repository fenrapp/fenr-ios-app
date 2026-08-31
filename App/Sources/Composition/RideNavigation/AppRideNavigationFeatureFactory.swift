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

    func makeFeature() -> RideNavigationFeatureModel {
        let repository = Self.makeRecordedRouteRepository()
        let iso8601 = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let placeSearch = ApplePlaceSearchService()
        let roadRouteCalculator = AppleRoadRouteCalculator()
        let mapLinkSecurityPolicy = AppleMapLinkSecurityPolicy.standard
        let redirectSession = Self.makeRedirectSession(policy: mapLinkSecurityPolicy)
        return RideNavigationFeatureModel(
            viewModel: RideNavigationViewModel(
                dependencies: RideNavigationViewModelDependencies(
                    vehicleSession: vehicleSession,
                    observeDeviceSpeed: observeDeviceSpeed,
                    routeLibrary: RideNavigationRouteLibraryService(
                        repository: repository,
                        importer: GPXRouteParser(
                            now: Date.init,
                            dateFormat: iso8601,
                            fallbackDateFormat: Date.ISO8601FormatStyle(),
                            limits: GPXRouteImportLimits(
                                maximumFileSizeBytes: Constants.maximumGPXFileSizeBytes,
                                maximumPointCount: Constants.maximumGPXPointCount
                            )
                        ),
                        exporter: GPXRouteExporter(dateFormat: iso8601)
                    ),
                    planning: RideNavigationPlanningService(
                        placeSearch: placeSearch,
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
                    guidance: AppleNavigationGuidanceClient(
                        synthesizer: AVSpeechSynthesizer(),
                        notificationGenerator: UINotificationFeedbackGenerator()
                    ),
                    loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
                    saveSettings: SaveAppSettingsUseCase(repository: settingsRepository),
                    presentationMapper: RideNavigationPresentationMapper(locale: .autoupdatingCurrent),
                    mapPresentationMapper: RideNavigationMapPresentationMapper(),
                    timing: .live
                ),
                recorder: RideRouteRecorder(),
                breadcrumbRecorder: RideRouteRecorder()
            ),
            mapSurfaceFactory: AppleNavigationMapSurfaceFactory().makeFactory()
        )
    }

    nonisolated private static func makeRecordedRouteRepository() -> FileRecordedRouteRepository {
        let fileManager = FileManager()
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return FileRecordedRouteRepository(
            fileManager: fileManager,
            directoryURL: base.appendingPathComponent("RideNavigation", isDirectory: true),
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
