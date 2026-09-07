import Foundation
import RideNavigationDomain

struct DebugNavigationRouteRepository: RecordedRouteRepository {
    let base: any RecordedRouteRepository
    let fault: DebugNavigationSaveFault

    func loadRoutes() async -> [RideRoute] { await base.loadRoutes() }
    func loadDraft() async -> RideRoute? { await base.loadDraft() }
    func saveDraft(_ route: RideRoute?) async throws { try await base.saveDraft(route) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }

    func save(_ route: RideRoute) async throws {
        if fault.consume() { throw CocoaError(.fileWriteUnknown) }
        try await base.save(route)
    }
}
