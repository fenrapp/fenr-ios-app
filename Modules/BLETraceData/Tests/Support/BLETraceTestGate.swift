actor BLETraceTestGate {
    private var isOpen = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var arrivalContinuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
            let arrivals = arrivalContinuations
            arrivalContinuations.removeAll()
            arrivals.forEach { $0.resume() }
        }
    }

    func waitUntilBlocked() async {
        guard releaseContinuation == nil, !isOpen else { return }
        await withCheckedContinuation { continuation in
            arrivalContinuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        releaseContinuation?.resume()
        releaseContinuation = nil
        let arrivals = arrivalContinuations
        arrivalContinuations.removeAll()
        arrivals.forEach { $0.resume() }
    }
}
