import Foundation

@MainActor
public final class ChargeControlStateEmitter {
    private var continuations: [UUID: AsyncStream<ChargeControlState>.Continuation] = [:]

    var subscriberCount: Int { continuations.count }

    public init() {}

    deinit {
        continuations.values.forEach { $0.finish() }
    }

    func stream(replaying state: ChargeControlState) -> AsyncStream<ChargeControlState> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<ChargeControlState>.makeStream(bufferingPolicy: .unbounded)
        continuations[identifier] = continuation
        continuation.onTermination = { [weak self] _ in
            // This bounded cleanup outlives the cancelled consumer and never publishes state.
            Task { @MainActor [weak self] in
                self?.continuations.removeValue(forKey: identifier)
            }
        }
        continuation.yield(state)
        return stream
    }

    func send(_ state: ChargeControlState) {
        for (identifier, continuation) in continuations {
            if case .terminated = continuation.yield(state) {
                continuations.removeValue(forKey: identifier)
            }
        }
    }
}
