import Foundation

final class WatchObservationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var changes = 0

    var count: Int { lock.withLock { changes } }

    func record() {
        lock.withLock { changes += 1 }
    }
}
