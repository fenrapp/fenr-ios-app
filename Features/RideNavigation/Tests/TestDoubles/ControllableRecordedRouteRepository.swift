import Foundation
import RideNavigationDomain

actor ControllableRecordedRouteRepository: RecordedRouteRepository {
    enum Failure: Error {
        case unavailable
    }

    private var routes: [RideRoute] = []
    private var saveRequests: [(RideRoute, CheckedContinuation<Void, any Error>)] = []
    private var loadContinuations: [CheckedContinuation<[RideRouteSummary], Never>] = []
    private var blocksLoads = false
    private var draftSaveContinuations: [CheckedContinuation<Void, any Error>] = []
    private var draftSaves = 0
    private(set) var saveWasCancelled: Bool?

    init(routes: [RideRoute] = []) {
        self.routes = routes
    }

    func loadRouteSummaries() async -> [RideRouteSummary] {
        if blocksLoads {
            return await withCheckedContinuation { continuation in
                loadContinuations.append(continuation)
            }
        }
        return routes.map(RideRouteSummary.init)
    }

    func loadRoute(id: UUID) async throws -> RideRoute? {
        routes.first { $0.id == id }
    }

    func save(_ route: RideRoute) async throws {
        try await withCheckedThrowingContinuation { continuation in
            saveRequests.append((route, continuation))
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

    func saveDraft(_: RideRoute?) async throws {
        draftSaves += 1
        try await withCheckedThrowingContinuation { continuation in
            draftSaveContinuations.append(continuation)
        }
    }

    var hasPendingSave: Bool {
        !saveRequests.isEmpty
    }

    func completeSave() {
        guard !saveRequests.isEmpty else { return }
        saveRequests.removeFirst().1.resume()
    }

    func failSave(request index: Int) {
        saveRequests.remove(at: index).1.resume(throwing: Failure.unavailable)
    }

    func succeedSave(request index: Int) {
        saveRequests.remove(at: index).1.resume()
    }

    var saveRequestCount: Int {
        saveRequests.count
    }

    var storedRoutes: [RideRoute] {
        routes
    }

    func blockRouteLoads() {
        blocksLoads = true
    }

    var pendingLoadCount: Int {
        loadContinuations.count
    }

    func resumeLoads(with routes: [RideRoute]) {
        blocksLoads = false
        let continuations = loadContinuations
        loadContinuations.removeAll()
        continuations.forEach { $0.resume(returning: routes.map(RideRouteSummary.init)) }
    }

    var draftSaveCount: Int {
        draftSaves
    }

    func completeDraftSaves() {
        let continuations = draftSaveContinuations
        draftSaveContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
