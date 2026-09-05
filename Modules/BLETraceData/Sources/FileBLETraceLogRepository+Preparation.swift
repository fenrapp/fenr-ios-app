import Foundation

extension FileBLETraceLogRepository {
    public func prepareStorage() async {
        guard !hasPreparedStorage else { return }
        do {
            try Self.prepareDirectories(
                directory: directory,
                exportDirectory: exportDirectory,
                fileManager: fileManager
            )
            try Self.removeDirectoryContents(exportDirectory, fileManager: fileManager)
            try Self.recoverPartialFiles(
                in: directory,
                fileManager: fileManager,
                codec: recordCodec,
                now: now()
            )
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
            hasPreparedStorage = true
            if recordingFailure?.phase == .preparing {
                recordingFailure = nil
                await failureHub.send(nil)
            }
        } catch {
            reconcileCompletedSessionsFromDisk()
            hasPreparedStorage = false
            if recordingFailure == nil || recordingFailure?.phase == .preparing {
                await reportRecordingFailure(sessionID: nil, phase: .preparing)
            }
        }
    }
}
