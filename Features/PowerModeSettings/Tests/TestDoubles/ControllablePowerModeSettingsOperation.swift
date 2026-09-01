import Foundation

actor ControllablePowerModeSettingsOperation {
    struct Failure: LocalizedError, Sendable {
        let message: String

        var errorDescription: String? { message }
    }

    private var continuations: [CheckedContinuation<Void, any Error>] = []
    private(set) var requestCount = 0

    var pendingCount: Int { continuations.count }

    func run() async throws {
        requestCount += 1
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func succeedNext() {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume()
    }

    func failNext(message: String) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(throwing: Failure(message: message))
    }

    func succeedAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
