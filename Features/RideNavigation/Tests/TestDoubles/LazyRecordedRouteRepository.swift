import Foundation
import RideNavigationDomain

actor LazyRecordedRouteRepository: RecordedRouteRepository {
    enum Failure: Error { case unavailable }

    private var summaries: [RideRouteSummary]
    private var pending: [(UUID, CheckedContinuation<RideRoute?, any Error>)] = []
    private var isClosed = false
    private(set) var detailLoadCount = 0

    init(summaries: [RideRouteSummary]) { self.summaries = summaries }

    func loadRouteSummaries() -> [RideRouteSummary] { summaries }

    func loadRoute(id: UUID) async throws -> RideRoute? {
        guard !isClosed else { throw CancellationError() }
        detailLoadCount += 1
        return try await withCheckedThrowingContinuation { pending.append((id, $0)) }
    }

    func close() {
        isClosed = true
        let unfinished = pending
        pending.removeAll()
        for (_, continuation) in unfinished {
            continuation.resume(throwing: CancellationError())
        }
    }

    func save(_ route: RideRoute) {
        summaries.removeAll { $0.id == route.id }
        summaries.insert(RideRouteSummary(route), at: 0)
    }

    func delete(id: UUID) { summaries.removeAll { $0.id == id } }
    func loadDraft() -> RideRoute? { nil }
    func saveDraft(_: RideRoute?) {}
    var pendingIDs: [UUID] { pending.map(\.0) }

    func complete(at index: Int = 0, route: RideRoute?) {
        pending.remove(at: index).1.resume(returning: route)
    }

    func fail(at index: Int = 0) {
        pending.remove(at: index).1.resume(throwing: Failure.unavailable)
    }
}
