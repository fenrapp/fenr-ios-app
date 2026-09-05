import BLETraceDomain
import Foundation

extension FileBLETraceLogRepository {
    @discardableResult
    func closeSession(
        _ originalSession: ActiveSession,
        endedAt: Date,
        reason: BLETraceSessionEndReason,
        status: BLETraceSessionStatus
    ) async -> Bool {
        guard var session = activeSession, session.context.id == originalSession.context.id else { return false }
        let durationMilliseconds = max(
            0,
            Int64(endedAt.timeIntervalSince(session.context.startedAt) * 1_000)
        )
        let footerInput = BLETraceRecordCodec.FooterInput(
            sessionID: session.context.id,
            endedAt: endedAt,
            durationMilliseconds: durationMilliseconds,
            eventCount: session.eventCount,
            baseBytes: session.bytesWritten,
            status: status,
            reason: reason
        )
        let finalURL = session.url.deletingPathExtension().appendingPathExtension("jsonl")
        do {
            let data = try recordCodec.encodeFooter(footerInput)
            try session.fileHandle.write(contentsOf: data)
            session.bytesWritten += Int64(data.count)
            try session.fileHandle.synchronize()
            try session.fileHandle.close()
            try Self.configureLogFile(session.url, fileManager: fileManager)
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            try fileManager.moveItem(at: session.url, to: finalURL)
            try Self.configureLogFile(finalURL, fileManager: fileManager)
            completedSessions = try Self.loadStoredSessions(
                in: directory,
                fileManager: fileManager,
                codec: recordCodec
            )
            completedSessions = try Self.prune(
                completedSessions,
                configuration: configuration,
                fileManager: fileManager,
                exportDirectory: exportDirectory
            )
        } catch {
            await closeActiveSessionAfterFailure(phase: .finishing)
            return false
        }
        activeSession = nil
        captureState.setRecording(false)
        await publishSessions()
        return true
    }

}
