import Foundation

actor ControllableRideHistoryOperation {
    enum Kind: Equatable, Hashable, Sendable {
        case history
        case detail(UUID)
        case deletion(UUID)
    }

    private struct RequestWaiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var blockedRequestCounts: [Kind: Int] = [:]
    private var pendingContinuations: [Kind: [CheckedContinuation<Void, Never>]] = [:]
    private var requestWaiters: [Kind: [RequestWaiter]] = [:]
    private var completionWaiters: [Kind: [RequestWaiter]] = [:]
    private(set) var requests: [Kind] = []
    private var completions: [Kind] = []

    func blockNext(_ kind: Kind) {
        blockedRequestCounts[kind, default: .zero] += 1
    }

    func perform(_ kind: Kind) async {
        requests.append(kind)
        resumeRequestWaiters(for: kind)

        if blockedRequestCounts[kind, default: .zero] > .zero {
            blockedRequestCounts[kind, default: .zero] -= 1
            await withCheckedContinuation { continuation in
                pendingContinuations[kind, default: []].append(continuation)
            }
        }
        completions.append(kind)
        resumeCompletionWaiters(for: kind)
    }

    func waitForRequest(_ kind: Kind, count: Int = 1) async {
        guard requestCount(for: kind) < count else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[kind, default: []].append(.init(count: count, continuation: continuation))
        }
    }

    func releaseNext(_ kind: Kind) {
        guard var continuations = pendingContinuations[kind], !continuations.isEmpty else { return }
        let continuation = continuations.removeFirst()
        pendingContinuations[kind] = continuations.isEmpty ? nil : continuations
        continuation.resume()
    }

    func waitForCompletion(_ kind: Kind, count: Int = 1) async {
        guard completionCount(for: kind) < count else { return }
        await withCheckedContinuation { continuation in
            completionWaiters[kind, default: []].append(.init(count: count, continuation: continuation))
        }
    }

    func requestCount(for kind: Kind) -> Int {
        requests.count { $0 == kind }
    }

    func pendingCount(for kind: Kind) -> Int {
        pendingContinuations[kind]?.count ?? .zero
    }

    private func completionCount(for kind: Kind) -> Int {
        completions.count { $0 == kind }
    }

    private func resumeRequestWaiters(for kind: Kind) {
        guard let waiters = requestWaiters[kind] else { return }
        let count = requestCount(for: kind)
        let ready = waiters.filter { $0.count <= count }
        let waiting = waiters.filter { $0.count > count }
        requestWaiters[kind] = waiting.isEmpty ? nil : waiting
        ready.forEach { $0.continuation.resume() }
    }

    private func resumeCompletionWaiters(for kind: Kind) {
        guard let waiters = completionWaiters[kind] else { return }
        let count = completionCount(for: kind)
        let ready = waiters.filter { $0.count <= count }
        let waiting = waiters.filter { $0.count > count }
        completionWaiters[kind] = waiting.isEmpty ? nil : waiting
        ready.forEach { $0.continuation.resume() }
    }
}
