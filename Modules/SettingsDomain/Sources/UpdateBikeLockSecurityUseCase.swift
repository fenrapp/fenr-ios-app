import Foundation

public struct UpdateBikeLockSecurityUseCase: Sendable {
    private let repository: any AppSettingsRepository
    private let credentialStore: any BikeLockCredentialStoring

    public init(
        repository: any AppSettingsRepository,
        credentialStore: any BikeLockCredentialStoring
    ) {
        self.repository = repository
        self.credentialStore = credentialStore
    }

    public func execute(
        vehicleIdentifier: String,
        securityMode: BikeLockSecurityMode,
        newPIN: String? = nil
    ) async throws {
        if securityMode.requiresPIN {
            if let newPIN {
                guard Self.isValidPIN(newPIN) else { throw BikeLockSecurityUpdateError.invalidPIN }
                try await credentialStore.save(pin: newPIN, for: vehicleIdentifier)
            }
        } else {
            try await credentialStore.removePIN(for: vehicleIdentifier)
        }

        var settings = await repository.load()
        settings.setBikeLockSettings(.init(securityMode: securityMode), forVIN: vehicleIdentifier)
        if securityMode.requiresPIN {
            settings.dashboardCardConfiguration.setSectionVisibility(true, id: .bikeLock)
        }
        await repository.save(settings)
    }

    public static func isValidPIN(_ pin: String) -> Bool {
        pin.utf8.count == 6 && pin.utf8.allSatisfy { $0 >= 48 && $0 <= 57 }
    }
}

public enum BikeLockSecurityUpdateError: LocalizedError, Equatable {
    case invalidPIN

    public var errorDescription: String? {
        "Enter a 6-digit PIN"
    }
}
