import LocalAuthentication
import SettingsDomain

struct LocalAuthenticationBikeLockAuthenticator: BikeLockAuthenticating {
    func authenticate(reason: String) async throws -> Bool {
        let context = LocalAuthenticationContext()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await context.authenticate(reason: reason)
        } onCancel: {
            context.invalidate()
        }
    }
}

private final class LocalAuthenticationContext: @unchecked Sendable {
    private let context = LAContext()

    init() {
        context.localizedFallbackTitle = "Enter PIN"
    }

    func authenticate(reason: String) async throws -> Bool {
        var authorizationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &authorizationError
        ) else {
            return false
        }
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    func invalidate() {
        context.invalidate()
    }
}
