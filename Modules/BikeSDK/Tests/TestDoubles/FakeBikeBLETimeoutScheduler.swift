import BikeSDK

@MainActor
final class FakeBikeBLETimeoutScheduler: BikeBLETimeoutScheduling {
    private var operation: (@MainActor @Sendable () async -> Void)?

    var hasPendingOperation: Bool {
        operation != nil
    }

    func schedule(operation: @escaping @MainActor @Sendable () async -> Void) {
        self.operation = operation
    }

    func cancel() {
        operation = nil
    }

    func fire() async {
        let pendingOperation = operation
        operation = nil
        await pendingOperation?()
    }
}
