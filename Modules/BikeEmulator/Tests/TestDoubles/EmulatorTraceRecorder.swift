import BLETraceDomain

actor EmulatorTraceRecorder: BLETraceRecording {
    let startsSuccessfully: Bool
    let finishesSuccessfully: Bool
    private(set) var starts: [BLETraceSessionContext] = []
    private(set) var events: [BLETraceEvent] = []
    private(set) var finishes: [BLETraceSessionEndReason] = []

    init(startsSuccessfully: Bool = true, finishesSuccessfully: Bool = true) {
        self.startsSuccessfully = startsSuccessfully
        self.finishesSuccessfully = finishesSuccessfully
    }

    func startSession(_ context: BLETraceSessionContext) async -> Bool {
        starts.append(context)
        return startsSuccessfully
    }

    func record(_ event: BLETraceEvent) async {
        events.append(event)
    }

    func finishSession(reason: BLETraceSessionEndReason) async -> Bool {
        finishes.append(reason)
        return finishesSuccessfully
    }
}
