import Foundation

public protocol RecordedRouteRepository: Sendable {
    func loadRoutes() async -> [RideRoute]
    func save(_ route: RideRoute) async throws
    func delete(id: UUID) async throws
    func loadDraft() async -> RideRoute?
    func saveDraft(_ route: RideRoute?) async throws
}

public protocol GPXRouteImporting: Sendable {
    func importRoutes(from data: Data, fallbackName: String) throws -> [RideRoute]
}

public protocol GPXRouteExporting: Sendable {
    func export(_ route: RideRoute) throws -> Data
}
