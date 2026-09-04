import Foundation

actor ControllableMaintenanceOperation {
    enum Kind: Equatable, Hashable, Sendable {
        case load
        case save
        case delete
    }

    private var blocked: Set<Kind> = []
    private var pending: [Kind: CheckedContinuation<Void, Never>] = [:]
    private var requestWaiters: [Kind: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var requests: [Kind] = []

    func blockNext(_ kind: Kind) {
        blocked.insert(kind)
    }

    func perform(_ kind: Kind) async {
        requests.append(kind)
        requestWaiters.removeValue(forKey: kind)?.forEach { $0.resume() }
        guard blocked.remove(kind) != nil else { return }
        await withCheckedContinuation { pending[kind] = $0 }
    }

    func waitForRequest(_ kind: Kind) async {
        guard !requests.contains(kind) else { return }
        await withCheckedContinuation { requestWaiters[kind, default: []].append($0) }
    }

    func release(_ kind: Kind) {
        pending.removeValue(forKey: kind)?.resume()
    }

    func requestCount(_ kind: Kind) -> Int {
        requests.count { $0 == kind }
    }
}
