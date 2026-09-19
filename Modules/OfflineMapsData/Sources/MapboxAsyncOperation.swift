import Foundation
import MapboxMaps

/// Serializes callback completion and cancellation, including cancellation before registration.
final class MapboxAsyncOperation<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var cancelable: Cancelable?
    private var result: Result<Value, Error>?

    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func install(_ cancelable: Cancelable?) {
        lock.lock()
        let finished = result != nil
        if !finished { self.cancelable = cancelable }
        lock.unlock()
        if finished { cancelable?.cancel() }
    }

    func finish(_ value: Result<Value, Error>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = value
        let continuation = continuation
        self.continuation = nil
        cancelable = nil
        lock.unlock()
        continuation?.resume(with: value)
    }

    func cancel() {
        lock.lock()
        let operation = cancelable
        lock.unlock()
        finish(.failure(CancellationError()))
        operation?.cancel()
    }

    @MainActor
    static func run(
        _ start: (@escaping @Sendable (Result<Value, Error>) -> Void) -> Cancelable?
    ) async throws -> Value {
        let operation = MapboxAsyncOperation<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.install(continuation)
                operation.install(start { operation.finish($0) })
            }
        } onCancel: {
            operation.cancel()
        }
    }
}
