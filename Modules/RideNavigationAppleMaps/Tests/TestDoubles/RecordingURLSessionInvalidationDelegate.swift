import Foundation

final class RecordingURLSessionInvalidationDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func urlSession(_: URLSession, didBecomeInvalidWithError _: (any Error)?) {
        lock.withLock {
            count += 1
        }
    }

    func invalidationCount() -> Int {
        lock.withLock { count }
    }
}
