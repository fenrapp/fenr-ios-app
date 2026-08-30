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
                lineEncoder: lineEncoder,
                now: now()
            )
            completedSessions = try Self.loadStoredSessions(
                in: directory,
                fileManager: fileManager
            )
            completedSessions = try Self.prune(
                completedSessions,
                configuration: configuration,
                fileManager: fileManager,
                exportDirectory: exportDirectory
            )
            hasPreparedStorage = true
        } catch {
            reconcileCompletedSessionsFromDisk()
            hasPreparedStorage = false
        }
    }
}
