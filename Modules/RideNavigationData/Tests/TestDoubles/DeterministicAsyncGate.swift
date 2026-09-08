import TestSupport

actor DeterministicAsyncGate {
    private var isOpen = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilBlocked() async -> Bool {
        await waitUntil { await self.hasArrived }
    }

    private var hasArrived: Bool {
        releaseContinuation != nil || isOpen
    }

    func open() {
        isOpen = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
