import LocalAuthentication
import RideDashboard

struct LocalAuthenticationBikeLockAuthenticator: BikeLockAuthenticating {
    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter PIN"
        var authorizationError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &authorizationError
        ) else {
            return false
        }
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock your motorcycle"
        )
    }
}
