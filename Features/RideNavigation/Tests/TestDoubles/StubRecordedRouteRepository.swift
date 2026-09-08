import Foundation
import RideNavigationDomain

actor StubRecordedRouteRepository: RecordedRouteRepository {
    private var routes: [RideRoute]
    private var draft: RideRoute?

    init(routes: [RideRoute] = [], draft: RideRoute? = nil) {
        self.routes = routes
        self.draft = draft
    }

    func loadRouteSummaries() async -> [RideRouteSummary] {
        routes.map(RideRouteSummary.init)
    }

    func loadRoute(id: UUID) async throws -> RideRoute? {
        routes.first { $0.id == id }
    }

    func save(_ route: RideRoute) async throws {
        routes.removeAll { $0.id == route.id }
        routes.append(route)
    }

    func delete(id: UUID) async throws {
        routes.removeAll { $0.id == id }
    }

    func loadDraft() async -> RideRoute? {
        draft
    }

    func saveDraft(_ route: RideRoute?) async throws {
        draft = route
    }
}
