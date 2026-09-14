import Foundation

@MainActor
public final class ChargingPreferencesEmitter {
    private var continuations: [UUID: AsyncStream<ChargingPreferencesState>.Continuation] = [:]

    public init() {}

    deinit { continuations.values.forEach { $0.finish() } }

    public func stream(replaying state: ChargingPreferencesState) -> AsyncStream<ChargingPreferencesState> {
        let id = UUID()
        let pair = AsyncStream<ChargingPreferencesState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = pair.continuation
        pair.continuation.yield(state)
        pair.continuation.onTermination = { @Sendable [weak self] _ in
            // Cleanup deliberately outlives the cancelled subscriber and never publishes state.
            Task { @MainActor in self?.continuations.removeValue(forKey: id) }
        }
        return pair.stream
    }

    func send(_ state: ChargingPreferencesState) {
        for continuation in continuations.values { continuation.yield(state) }
    }
}
