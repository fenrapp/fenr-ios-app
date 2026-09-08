import Foundation
import RideNavigationDomain

actor LibraryControllerRouteRepository: RecordedRouteRepository {
    enum Failure: Error { case unavailable }

    private var routes: [RideRoute]
    private var draft: RideRoute?
    private var blocksLoads = false
    private var blocksDrafts = false
    private var pendingLoads: [CheckedContinuation<[RideRouteSummary], Never>] = []
    private var pendingSaves: [(RideRoute, CheckedContinuation<Void, any Error>)] = []
    private var pendingDeletes: [UUID: [CheckedContinuation<Void, any Error>]] = [:]
    private var pendingDrafts: [(RideRoute?, CheckedContinuation<Void, any Error>)] = []
    private(set) var savedRoutes: [RideRoute] = []
    private(set) var savedDraftIDs: [UUID?] = []
    private(set) var saveCancellationStates: [Bool] = []
    private(set) var loadCount = 0

    init(routes: [RideRoute] = []) {
        self.routes = routes
    }

    func loadRouteSummaries() async -> [RideRouteSummary] {
        loadCount += 1
        guard blocksLoads else { return routes.map(RideRouteSummary.init) }
        return await withCheckedContinuation { pendingLoads.append($0) }
    }

    func loadRoute(id: UUID) async throws -> RideRoute? {
        routes.first { $0.id == id }
    }

    func save(_ route: RideRoute) async throws {
        try await withCheckedThrowingContinuation { pendingSaves.append((route, $0)) }
        saveCancellationStates.append(Task.isCancelled)
        routes.removeAll { $0.id == route.id }
        routes.append(route)
        savedRoutes.append(route)
    }

    func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation { pendingDeletes[id, default: []].append($0) }
        routes.removeAll { $0.id == id }
    }

    func loadDraft() -> RideRoute? { draft }

    func saveDraft(_ route: RideRoute?) async throws {
        if blocksDrafts {
            try await withCheckedThrowingContinuation { pendingDrafts.append((route, $0)) }
        }
        draft = route
        savedDraftIDs.append(route?.id)
    }

    var pendingLoadCount: Int { pendingLoads.count }
    var pendingSaveCount: Int { pendingSaves.count }
    var pendingDeleteIDs: Set<UUID> { Set(pendingDeletes.keys) }
    var pendingDraftCount: Int { pendingDrafts.count }
    var pendingDeleteCount: Int { pendingDeletes.values.reduce(0) { $0 + $1.count } }

    func blockLoads() { blocksLoads = true }
    func unblockLoads() { blocksLoads = false }
    func blockDrafts() { blocksDrafts = true }
    func unblockDrafts() { blocksDrafts = false }

    func resumeLoad(at index: Int = 0, routes: [RideRoute]) {
        pendingLoads.remove(at: index).resume(returning: routes.map(RideRouteSummary.init))
    }

    func completeSave(at index: Int = 0) {
        pendingSaves.remove(at: index).1.resume()
    }

    func failSave(at index: Int = 0) {
        pendingSaves.remove(at: index).1.resume(throwing: Failure.unavailable)
    }

    func completeDelete(id: UUID) {
        takeDelete(id: id)?.resume()
    }

    func failDelete(id: UUID) {
        takeDelete(id: id)?.resume(throwing: Failure.unavailable)
    }

    private func takeDelete(id: UUID) -> CheckedContinuation<Void, any Error>? {
        guard var pending = pendingDeletes[id], !pending.isEmpty else { return nil }
        let next = pending.removeFirst()
        pendingDeletes[id] = pending.isEmpty ? nil : pending
        return next
    }

    func completeDraft(at index: Int = 0) {
        pendingDrafts.remove(at: index).1.resume()
    }
}
