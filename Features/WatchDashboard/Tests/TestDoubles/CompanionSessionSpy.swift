import Foundation
import WatchCompanionDomain

@MainActor
final class CompanionSessionSpy: CompanionSession {
    private var continuations: [UUID: AsyncStream<CompanionState>.Continuation] = [:]
    var subscriberCount: Int { continuations.count }
    private(set) var activations = 0
    private(set) var refreshes = 0
    private(set) var observations = 0

    func activate() { activations += 1 }
    func requestLatest() { refreshes += 1 }
    func observe() -> AsyncStream<CompanionState> {
        observations += 1
        let (stream, continuation) = AsyncStream<CompanionState>.makeStream()
        let identifier = UUID()
        continuations[identifier] = continuation
        continuation.onTermination = { [weak self] _ in
            DispatchQueue.main.async { self?.continuations.removeValue(forKey: identifier) }
        }
        return stream
    }
    func send(_ state: CompanionState) {
        for continuation in continuations.values { continuation.yield(state) }
    }
}
