actor SleepCallRecorder<Value: Sendable> {
    private var values: [Value] = []
    private var callWaiters: [CallWaiter] = []

    func record(_ value: Value) {
        values.append(value)
        resumeSatisfiedWaiters()
    }

    func waitForCall(count: Int = 1) async {
        guard values.count < count else { return }

        await withCheckedContinuation { continuation in
            callWaiters.append(.init(count: count, continuation: continuation))
        }
    }

    func recordedValues() -> [Value] {
        values
    }

    private func resumeSatisfiedWaiters() {
        var pendingWaiters: [CallWaiter] = []
        for waiter in callWaiters {
            if values.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                pendingWaiters.append(waiter)
            }
        }
        callWaiters = pendingWaiters
    }

    private struct CallWaiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }
}
