import Foundation
import SettingsDomain

actor ControllableBikeLockSettingsAuthenticator: BikeLockAuthenticating {
    enum Outcome: Sendable {
        case success(Bool)
        case cancellation
    }

    private var outcome: Outcome
    private var shouldBlock = false
    private var authenticationCount = 0
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    init(outcome: Outcome = .success(true)) {
        self.outcome = outcome
    }

    func authenticate(reason _: String) async throws -> Bool {
        authenticationCount += 1
        if shouldBlock {
            let id = UUID()
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    waiters[id] = continuation
                }
            } onCancel: {
                Task { await self.cancelWaiter(id: id) }
            }
        }
        try Task.checkCancellation()
        switch outcome {
        case .success(let result): return result
        case .cancellation: throw CancellationError()
        }
    }

    func setOutcome(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func block() {
        shouldBlock = true
    }

    func release() {
        shouldBlock = false
        let pending = Array(waiters.values)
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }

    func callCount() -> Int { authenticationCount }

    private func cancelWaiter(id: UUID) {
        waiters.removeValue(forKey: id)?.resume()
    }
}
