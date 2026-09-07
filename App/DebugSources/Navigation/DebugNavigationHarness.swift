import EnvironmentDomain
import Foundation
import RideNavigation
import RideNavigationData
import RideNavigationDomain

@MainActor
struct DebugNavigationHarness {
    let deviceSpeedRepository: DebugNavigationLocationSource
    let controls: DebugNavigationControls
    let makeFeatureFactory: AppRideNavigationFactoryBuilder

    static func make(directory: URL) -> DebugNavigationHarness {
        let clock = DebugNavigationClock(initialDate: Date(timeIntervalSince1970: 1_750_000_000))
        let source = DebugNavigationLocationSource(clock: clock)
        let fault = DebugNavigationSaveFault()
        let repository = DebugNavigationRouteRepository(
            base: FileRecordedRouteRepository(
                fileManager: FileManager(), directoryURL: directory, codec: StoredRideRouteCodec()
            ),
            fault: fault
        )
        let dateFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let library = RideNavigationRouteLibraryService(
            repository: repository,
            importer: GPXRouteParser(
                now: clock.now,
                dateFormat: dateFormat,
                fallbackDateFormat: Date.ISO8601FormatStyle(),
                limits: GPXRouteImportLimits(maximumFileSizeBytes: 25 * 1_024 * 1_024, maximumPointCount: 100_000)
            ),
            exporter: GPXRouteExporter(dateFormat: dateFormat)
        )
        guard let destinationCoordinate = GeographicCoordinate(latitudeDegrees: 40.428, longitudeDegrees: -3.703) else {
            preconditionFailure("Invalid synthetic navigation coordinate")
        }
        let planning = DebugNavigationPlanningService(destination: .init(
            name: String(localized: .uiTestingNavigationDestinationTitle),
            detail: String(localized: .uiTestingNavigationDestinationDetail),
            coordinate: destinationCoordinate
        ))
        let timing = RideNavigationTiming(now: clock.now, sleep: { try await Task.sleep(for: $0) })
        return DebugNavigationHarness(
            deviceSpeedRepository: source,
            controls: DebugNavigationControls(source: source, fault: fault),
            makeFeatureFactory: { context in
                DebugNavigationFeatureFactory(
                    context: context, routeLibrary: library, planningService: planning, timing: timing
                )
            }
        )
    }
}
