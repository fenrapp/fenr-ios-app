@testable import BLETraceData

extension FileBLETraceLogRepository {
    /// Reproduce a failed OS write after a successful header without altering production behavior.
    func closeActiveFileHandleForTesting() throws {
        try activeSession?.fileHandle.close()
    }
}
