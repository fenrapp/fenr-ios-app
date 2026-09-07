import Foundation

final class DebugNavigationClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(initialDate: Date) {
        value = initialDate
    }

    func now() -> Date { lock.withLock { value } }

    func advance() -> Date {
        lock.withLock {
            value = value.addingTimeInterval(10)
            return value
        }
    }
}
