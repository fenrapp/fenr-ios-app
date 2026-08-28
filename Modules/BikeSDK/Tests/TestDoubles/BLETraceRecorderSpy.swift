import BLETraceDomain

actor BLETraceRecorderSpy: BLETraceRecording {
    private(set) var contexts: [BLETraceSessionContext] = []
    private(set) var events: [BLETraceEvent] = []
    private(set) var endReasons: [BLETraceSessionEndReason] = []
    private var shouldSuspendNextStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?

    func startSession(_ context: BLETraceSessionContext) async {
        contexts.append(context)
        guard shouldSuspendNextStart else { return }
        shouldSuspendNextStart = false
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func record(_ event: BLETraceEvent) {
        events.append(event)
    }

    func finishSession(reason: BLETraceSessionEndReason) {
        endReasons.append(reason)
    }

    func recordedEvents() -> [BLETraceEvent] {
        events
    }

    func suspendNextStart() {
        shouldSuspendNextStart = true
    }

    func isStartSuspended() -> Bool {
        startContinuation != nil
    }

    func resumeStart() {
        startContinuation?.resume()
        startContinuation = nil
    }
}
