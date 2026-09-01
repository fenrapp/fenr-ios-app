import BikeDomain
import Foundation

@MainActor
final class BikeLockSettingsTestCapabilityStore: BikeLockCapabilityStateStoring {
    private(set) var currentState: BikeLockCapabilityState
    private var continuations: [UUID: AsyncStream<BikeLockCapabilityState>.Continuation] = [:]

    init(state: BikeLockCapabilityState) {
        currentState = state
    }

    func update(_ state: BikeLockCapabilityState) {
        currentState = state
        continuations.values.forEach { $0.yield(state) }
    }

    func observe() -> AsyncStream<BikeLockCapabilityState> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuations[id] = continuation
            continuation.yield(currentState)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    var observerCount: Int { continuations.count }
}
