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
        return stream
    }
}
