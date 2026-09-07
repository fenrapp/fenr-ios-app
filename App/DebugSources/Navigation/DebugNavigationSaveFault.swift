import Foundation

final class DebugNavigationSaveFault: @unchecked Sendable {
    private let lock = NSLock()
    private var isArmed = false

    func arm() { lock.withLock { isArmed = true } }

    func consume() -> Bool {
        lock.withLock {
            defer { isArmed = false }
            return isArmed
        }
    }
}
