import BLETraceDomain

@MainActor
final class BLETraceSessionSnapshotRecorder {
    var snapshot: [BLETraceSessionSummary]?
}
