import Foundation
import SettingsDomain

public struct BikeLockSettingsSecurityService: Sendable {
    private let credentialStore: any BikeLockCredentialStoring
    private let authenticator: any BikeLockAuthenticating
    private let updateSecurity: UpdateBikeLockSecurityUseCase

    public init(
        credentialStore: any BikeLockCredentialStoring,
        authenticator: any BikeLockAuthenticating,
        updateSecurity: UpdateBikeLockSecurityUseCase
    ) {
        self.credentialStore = credentialStore
        self.authenticator = authenticator
        self.updateSecurity = updateSecurity
    }

    func verify(pin: String, for vehicleIdentifier: String) async throws {
        guard await credentialStore.verify(pin: pin, for: vehicleIdentifier) else {
            throw BikeLockSettingsError.incorrectPIN
        }
    }

    func authenticate(for vehicleIdentifier: String) async throws -> Bool {
        guard await credentialStore.containsPIN(for: vehicleIdentifier) else {
            throw BikeLockSettingsError.missingCredential
        }
        do {
            return try await authenticator.authenticate(
                reason: String(localized: .bikeLockSettingsAuthenticationReason)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return false
        }
    }

    func update(
        vehicleIdentifier: String,
        mode: BikeLockSecurityMode,
        newPIN: String?
    ) async throws {
        try await updateSecurity.execute(
            vehicleIdentifier: vehicleIdentifier,
            securityMode: mode,
            newPIN: newPIN
        )
    }
}

enum BikeLockSettingsError: LocalizedError {
    case incorrectPIN
    case missingCredential
    case pinMismatch

    var errorDescription: String? {
        switch self {
        case .incorrectPIN: String(localized: .bikeLockSettingsIncorrectPINError)
        case .missingCredential: String(localized: .bikeLockSettingsMissingCredentialError)
        case .pinMismatch: String(localized: .bikeLockSettingsPINMismatchError)
        }
    }
}
