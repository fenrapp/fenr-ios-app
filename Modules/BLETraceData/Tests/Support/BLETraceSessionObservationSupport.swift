import BLETraceDomain
import Testing
import TestSupport

@MainActor
func firstBLETraceSessionSnapshot(
    from stream: AsyncStream<[BLETraceSessionSummary]>
) async throws -> [BLETraceSessionSummary] {
    let recorder = BLETraceSessionSnapshotRecorder()
    let task = Task {
        for await snapshot in stream {
            recorder.snapshot = snapshot
            return
        }
    }
    let receivedSnapshot = await waitUntil { recorder.snapshot != nil }
    task.cancel()
    await task.value
    try #require(receivedSnapshot, "Expected the initial session snapshot within the bounded wait")
    return try #require(recorder.snapshot)
}
