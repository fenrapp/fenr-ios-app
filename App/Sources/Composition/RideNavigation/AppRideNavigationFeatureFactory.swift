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
        let redirectConfiguration = URLSessionConfiguration.ephemeral
        redirectConfiguration.timeoutIntervalForRequest = Constants.mapLinkTimeoutSeconds
        redirectConfiguration.timeoutIntervalForResource = Constants.mapLinkTimeoutSeconds
        let redirectDelegate = AllowedMapLinkRedirectDelegate(
            allowedHosts: Constants.allowedMapLinkHosts,
            maximumRedirects: Constants.maximumMapLinkRedirects
        )
        let redirectSession = URLSession(
            configuration: redirectConfiguration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
        return RideNavigationFeatureModel(
            viewModel: RideNavigationViewModel(
                vehicleSession: vehicleSession,
                observeDeviceSpeed: observeDeviceSpeed,
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
                exporter: GPXRouteExporter(dateFormat: iso8601),
                placeSearch: placeSearch,
                roadRouteCalculator: roadRouteCalculator,
                externalMapLinkResolver: AppleExternalMapLinkResolver(
                    redirectResolver: URLSessionMapLinkRedirectResolver(session: redirectSession),
                    placeSearch: placeSearch
                ),
                trailExitFinder: AppleTrailExitFinder(
                    candidateSearch: AppleTrailExitCandidateSearch(),
                    roadRouteCalculator: roadRouteCalculator
                ),
                guidance: AppleNavigationGuidanceClient(
                    synthesizer: AVSpeechSynthesizer(),
                    notificationGenerator: UINotificationFeedbackGenerator()
                ),
                loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
                saveSettings: SaveAppSettingsUseCase(repository: settingsRepository),
                mapper: RideNavigationPresentationMapper(locale: .autoupdatingCurrent),
                recorder: RideRouteRecorder(),
                breadcrumbRecorder: RideRouteRecorder(),
                now: Date.init
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

    private enum Constants {
        static let mapLinkTimeoutSeconds: TimeInterval = 5
        static let maximumMapLinkRedirects = 5
        static let maximumGPXFileSizeBytes = 25 * 1_024 * 1_024
        static let maximumGPXPointCount = 100_000
        static let allowedMapLinkHosts: Set<String> = [
            "maps.app.goo.gl",
            "goo.gl",
            "google.com",
            "www.google.com",
            "maps.google.com",
            "maps.apple.com"
        ]
    }
}
