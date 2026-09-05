import Foundation

/// Shared admission gate for optional diagnostic work. A new process always starts disabled.
public final class BLETraceCaptureState: @unchecked Sendable {
    private let lock = NSLock()
    private var recording = false

    public init() {}

    public var isRecording: Bool {
        lock.withLock { recording }
    }

    public func setRecording(_ value: Bool) {
        lock.withLock { recording = value }
    }
}
