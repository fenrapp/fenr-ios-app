import Foundation
import LocalAuthentication

enum BikeLockAuthenticationFactory {
    static func makeAuthenticator() -> LocalAuthenticationBikeLockAuthenticator {
        LocalAuthenticationBikeLockAuthenticator {
            let context = LAContext()
            context.localizedFallbackTitle = String(localized: .appBikeLockEnterPIN)
            return LocalAuthenticationContext(context: context)
        }
    }
}
