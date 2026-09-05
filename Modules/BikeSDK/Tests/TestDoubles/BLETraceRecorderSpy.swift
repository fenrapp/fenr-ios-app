import BLETraceDomain

actor BLETraceRecorderSpy: BLETraceRecording {
    private(set) var contexts: [BLETraceSessionContext] = []
    private(set) var events: [BLETraceEvent] = []
    private(set) var endReasons: [BLETraceSessionEndReason] = []
    private var shouldSuspendNextStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var shouldSuspendNextRecord = false
    private var recordContinuation: CheckedContinuation<Void, Never>?
    private var shouldSuspendNextFinish = false
    private var shouldFailFinish = false
    private var finishContinuation: CheckedContinuation<Void, Never>?

    func startSession(_ context: BLETraceSessionContext) async -> Bool {
        contexts.append(context)
        guard shouldSuspendNextStart else { return true }
        shouldSuspendNextStart = false
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
        return true
    }

    func record(_ event: BLETraceEvent) async {
        events.append(event)
        guard shouldSuspendNextRecord else { return }
        shouldSuspendNextRecord = false
        await withCheckedContinuation { continuation in
            recordContinuation = continuation
        }
    }

    func finishSession(reason: BLETraceSessionEndReason) async -> Bool {
        endReasons.append(reason)
        guard shouldSuspendNextFinish else { return !shouldFailFinish }
        shouldSuspendNextFinish = false
        await withCheckedContinuation { continuation in
            finishContinuation = continuation
        }
        return !shouldFailFinish
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

    func suspendNextRecord() {
        shouldSuspendNextRecord = true
    }

    func isRecordSuspended() -> Bool {
        recordContinuation != nil
    }

    func resumeRecord() {
        recordContinuation?.resume()
        recordContinuation = nil
    }

    func failFinish() {
        shouldFailFinish = true
    }

    func suspendNextFinish() {
        shouldSuspendNextFinish = true
    }

    func isFinishSuspended() -> Bool {
        finishContinuation != nil
    }

    func resumeFinish() {
        finishContinuation?.resume()
        finishContinuation = nil
    }
}
