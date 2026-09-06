import Foundation

final class ControlledBikeLockAuthenticationContext: BikeLockAuthenticationContext, @unchecked Sendable {
    private let lock = NSLock()
    private let immediateResult: Bool?
    private var pending: CheckedContinuation<Bool, Error>?
    private var reasons: [String] = []
    private var invalidations = 0

    init(immediateResult: Bool? = nil) {
        self.immediateResult = immediateResult
    }

    var requestedReasons: [String] { lock.withLock { reasons } }
    var invalidationCount: Int { lock.withLock { invalidations } }
    var isPending: Bool { lock.withLock { pending != nil } }

    func authenticate(reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                reasons.append(reason)
                if let immediateResult {
                    continuation.resume(returning: immediateResult)
                } else {
                    pending = continuation
                }
            }
        }
    }

    func invalidate() {
        lock.withLock { invalidations += 1 }
    }

    func finish(with result: Result<Bool, Error>) {
        let continuation = lock.withLock {
            defer { pending = nil }
            return pending
        }
        continuation?.resume(with: result)
    }
}

final class FakeBikeLockAuthenticationContextFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var created: [ControlledBikeLockAuthenticationContext] = []

    var contexts: [ControlledBikeLockAuthenticationContext] { lock.withLock { created } }

    func make() -> any BikeLockAuthenticationContext {
        let context = ControlledBikeLockAuthenticationContext(immediateResult: true)
        lock.withLock { created.append(context) }
        return context
    }
}
