import BikeDomain
import Foundation

@MainActor
final class DashboardCardSettingsBikeLockCapabilityStore: BikeLockCapabilityStateStoring {
    private(set) var currentState: BikeLockCapabilityState
    private var continuations: [UUID: AsyncStream<BikeLockCapabilityState>.Continuation] = [:]

    init(state: BikeLockCapabilityState = .init()) {
        currentState = state
    }

    func update(_ state: BikeLockCapabilityState) {
        currentState = state
        continuations.values.forEach { $0.yield(state) }
    }

    func observe() -> AsyncStream<BikeLockCapabilityState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<BikeLockCapabilityState>.makeStream()
        continuations[id] = continuation
        continuation.yield(currentState)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.removeContinuation(id)
            }
        }
        return stream
    }

    var observerCount: Int {
        continuations.count
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
