import BLETraceDomain

actor LifecycleBLETraceStoragePreparer: BLETraceStoragePreparing {
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func prepareStorage() async {
        hasStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func preparationHasStarted() -> Bool {
        hasStarted
    }

    func finishPreparation() {
        continuation?.resume()
        continuation = nil
    }
}
