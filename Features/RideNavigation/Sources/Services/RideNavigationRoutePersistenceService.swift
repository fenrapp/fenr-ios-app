import RideNavigationDomain

public struct RideNavigationRoutePersistenceService: Sendable {
    private let repository: any RecordedRouteRepository

    public init(repository: any RecordedRouteRepository) {
        self.repository = repository
    }

    func saveAndReload(_ route: RideRoute) async throws -> [RideRoute] {
        try await repository.save(route)
        try Task.checkCancellation()
        let routes = await repository.loadRoutes()
        try Task.checkCancellation()
        return routes
    }
}
