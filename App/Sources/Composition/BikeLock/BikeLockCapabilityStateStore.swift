import BikeDomain
import Foundation

@MainActor
final class BikeLockCapabilityStateStore: BikeLockCapabilityStateStoring {
    private(set) var currentState = BikeLockCapabilityState()
    private var continuations: [UUID: AsyncStream<BikeLockCapabilityState>.Continuation] = [:]

    func update(_ state: BikeLockCapabilityState) {
        guard state != currentState else { return }
        currentState = state
        continuations.values.forEach { $0.yield(state) }
    }

    func observe() -> AsyncStream<BikeLockCapabilityState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<BikeLockCapabilityState>.makeStream()
        continuations[id] = continuation
        continuation.yield(currentState)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.removeContinuation(id) }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
