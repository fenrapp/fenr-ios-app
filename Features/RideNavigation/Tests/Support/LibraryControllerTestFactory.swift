import Foundation
@testable import RideNavigation
import RideNavigationDomain

enum LibraryControllerTestFactory {
    @MainActor
    static func makeController(
        repository: any RecordedRouteRepository,
        importer: any GPXRouteImporting = StubGPXRouteImporter()
    ) -> RideNavigationLibraryController {
        RideNavigationLibraryController(
            routeLibrary: RideNavigationRouteLibraryService(
                repository: repository,
                importer: importer,
                exporter: StubGPXRouteExporter()
            ),
            timing: RideNavigationTiming(
                now: { Date(timeIntervalSince1970: 1_700_000_000) },
                sleep: { _ in try Task.checkCancellation() }
            )
        )
    }
}
