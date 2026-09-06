import SettingsDomain

struct LocalAuthenticationBikeLockAuthenticator: BikeLockAuthenticating {
    let makeContext: @Sendable () -> any BikeLockAuthenticationContext

    func authenticate(reason: String) async throws -> Bool {
        try Task.checkCancellation()
        let context = makeContext()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let authenticated = try await context.authenticate(reason: reason)
            try Task.checkCancellation()
            return authenticated
        } onCancel: {
            context.invalidate()
        }
    }
}
