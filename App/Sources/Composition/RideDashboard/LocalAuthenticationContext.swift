import LocalAuthentication

final class LocalAuthenticationContext: BikeLockAuthenticationContext, @unchecked Sendable {
    private let context: LAContext

    init(context: LAContext) {
        self.context = context
    }

    func authenticate(reason: String) async throws -> Bool {
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
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
