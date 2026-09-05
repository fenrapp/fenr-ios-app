import BLETraceDomain
import Foundation

extension FileBLETraceLogRepository {
    public func observeRecordingFailures() async -> AsyncStream<BLETraceRecordingFailure?> {
        await failureHub.stream(replay: .some(recordingFailure))
    }

    func reportRecordingFailure(sessionID: UUID?, phase: BLETraceRecordingFailure.Phase) async {
        let failure = BLETraceRecordingFailure(sessionID: sessionID, phase: phase)
        recordingFailure = failure
        await failureHub.send(failure)
    }
    static func incompleteSession(
        at url: URL,
        fileManager: FileManager,
        codec: BLETraceRecordCodec
    ) -> StoredSession? {
        guard let first = try? firstJSONLine(at: url),
              let header = codec.decodeHeaderBoundary(first),
              let statistics = try? streamStatistics(at: url) else { return nil }
        let footer = (try? lastJSONLine(at: url)).flatMap {
            codec.decodeSessionBoundary(headerData: first, footerData: $0)
        }
        return StoredSession(
            summary: BLETraceSessionSummary(
                id: header.sessionID,
                startedAt: header.startedAt,
                endedAt: nil,
                duration: nil,
                fileSizeBytes: fileSize(url, fileManager: fileManager),
                eventCount: footer?.eventCount ?? max(0, statistics.recordCount - 1),
                status: .incomplete,
                fileName: url.deletingPathExtension().lastPathComponent + ".jsonl"
            ),
            url: url
        )
    }
}
