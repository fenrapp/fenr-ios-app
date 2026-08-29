import Foundation
import RideNavigationDomain

actor ControllableRecordedRouteRepository: RecordedRouteRepository {
    private var routes: [RideRoute] = []
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private(set) var saveWasCancelled: Bool?

    func loadRoutes() async -> [RideRoute] {
        routes
    }

    func save(_ route: RideRoute) async throws {
        await withCheckedContinuation { continuation in
            saveContinuation = continuation
        }
        saveWasCancelled = Task.isCancelled
        routes.append(route)
    }

    func delete(id: UUID) async throws {
        routes.removeAll { $0.id == id }
    }

    func loadDraft() async -> RideRoute? {
        nil
    }

    func saveDraft(_: RideRoute?) async throws {}

    var hasPendingSave: Bool {
        saveContinuation != nil
    }

    func completeSave() {
        saveContinuation?.resume()
        saveContinuation = nil
    }
}
