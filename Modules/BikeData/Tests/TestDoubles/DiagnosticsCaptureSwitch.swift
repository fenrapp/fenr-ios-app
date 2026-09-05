import Foundation

final class DiagnosticsCaptureSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false

    var isEnabled: Bool { lock.withLock { enabled } }

    func enable() { lock.withLock { enabled = true } }
}
