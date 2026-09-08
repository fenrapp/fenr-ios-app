import Foundation

final class DashboardMapperCallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [String: Int] = [:]

    func record(_ name: String) { lock.withLock { calls[name, default: 0] += 1 } }
    func count(_ name: String) -> Int { lock.withLock { calls[name, default: 0] } }
}
