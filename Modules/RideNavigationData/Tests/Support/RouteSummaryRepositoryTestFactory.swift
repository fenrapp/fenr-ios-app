import Foundation
import RideNavigationData
import RideNavigationDomain

enum RouteSummaryRepositoryTestFactory {
    static func make(
        directory: TemporaryRouteDirectory,
        codec: any StoredRideRouteCoding
    ) -> FileRecordedRouteRepository {
        FileRecordedRouteRepository(fileManager: FileManager(), directoryURL: directory.url, codec: codec)
    }

    static func makeReplacingRouteAfterSave(
        directory: TemporaryRouteDirectory,
        replacement: RideRoute,
        codec: any StoredRideRouteCoding
    ) throws -> FileRecordedRouteRepository {
        let fileManager = ReplacingRouteFileManager(
            replacementURL: directory.routeURL(id: replacement.id),
            replacementData: try codec.encode(replacement)
        )
        return FileRecordedRouteRepository(fileManager: fileManager, directoryURL: directory.url, codec: codec)
    }
}
