import Foundation
import RideNavigationDomain

public struct RideNavigationRouteLibraryService: Sendable {
    let repository: any RecordedRouteRepository
    let importer: any GPXRouteImporting
    let exporter: any GPXRouteExporting

    public init(
        repository: any RecordedRouteRepository,
        importer: any GPXRouteImporting,
        exporter: any GPXRouteExporting
    ) {
        self.repository = repository
        self.importer = importer
        self.exporter = exporter
    }

    func loadRoutes() async -> [RideRoute] {
        await repository.loadRoutes()
    }

    func save(_ route: RideRoute) async throws {
        try await repository.save(route)
    }

    func saveAndReload(_ route: RideRoute) async throws -> [RideRoute] {
        try await repository.save(route)
        try Task.checkCancellation()
        let routes = await repository.loadRoutes()
        try Task.checkCancellation()
        return routes
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func saveDraft(_ route: RideRoute?) async throws {
        try await repository.saveDraft(route)
    }

    func importRoutes(from data: Data, fallbackName: String) throws -> [RideRoute] {
        try importer.importRoutes(from: data, fallbackName: fallbackName)
    }

    func export(_ route: RideRoute) throws -> Data {
        try exporter.export(route)
    }
}
