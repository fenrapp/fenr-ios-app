import Foundation
@testable import RideNavigation
import RideNavigationDomain

final class ActivityControllerTrailMapPreparer: RideNavigationTrailMapPreparing, @unchecked Sendable {
    private let lock = NSLock()
    private var isFinished = false
    private var requests: [UUID: CheckedContinuation<RideNavigationTrailMapPlan?, Never>] = [:]

    func prepare(route: RideRoute, direction _: RideRouteDirection) async -> RideNavigationTrailMapPlan? {
        await withCheckedContinuation { continuation in
            let shouldFinish = lock.withLock {
                guard !isFinished else { return true }
                requests[route.id] = continuation
                return false
            }
            if shouldFinish { continuation.resume(returning: nil) }
        }
    }

    func hasRequest(routeID: UUID) -> Bool { lock.withLock { requests[routeID] != nil } }

    func complete(routeID: UUID, plan: RideNavigationTrailMapPlan?) {
        let request = lock.withLock { requests.removeValue(forKey: routeID) }
        request?.resume(returning: plan)
    }

    func finish() {
        let pending = lock.withLock {
            isFinished = true
            let pending = Array(requests.values)
            requests = [:]
            return pending
        }
        pending.forEach { $0.resume(returning: nil) }
    }
}
