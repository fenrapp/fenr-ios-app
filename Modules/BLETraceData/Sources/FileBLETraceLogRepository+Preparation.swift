import Foundation

extension FileBLETraceLogRepository {
    public func prepareStorage() async {
        guard !hasPreparedStorage else { return }
        hasPreparedStorage = true
        do {
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
                fileManager: fileManager
            )
        } catch {
            completedSessions = []
        }
    }
}
