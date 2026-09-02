import BikeDomain
import SettingsDomain

public struct BikeLockCardOperationService: Sendable {
    enum AuthenticationResult: Sendable {
        case unlocked(BikeLockControlSnapshot)
        case requiresPIN
        case writeFailed(String)
    }

    private let prepareControl: PrepareBikeLockControlUseCase
    private let setLocked: SetBikeLockedUseCase
    private let updateSecurity: UpdateBikeLockSecurityUseCase
    private let credentialStore: any BikeLockCredentialStoring
    private let authenticator: any BikeLockAuthenticating

    public init(
        prepareControl: PrepareBikeLockControlUseCase,
        setLocked: SetBikeLockedUseCase,
        updateSecurity: UpdateBikeLockSecurityUseCase,
        credentialStore: any BikeLockCredentialStoring,
        authenticator: any BikeLockAuthenticating
    ) {
        self.prepareControl = prepareControl
        self.setLocked = setLocked
        self.updateSecurity = updateSecurity
        self.credentialStore = credentialStore
        self.authenticator = authenticator
    }

    func prepare() async throws -> BikeLockControlSnapshot {
        try await prepareControl.execute()
    }

    func configure(
        vehicleIdentifier: String,
        mode: BikeLockSecurityMode,
        pin: String?,
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> BikeLockControlSnapshot {
        try await updateSecurity.execute(
            vehicleIdentifier: vehicleIdentifier,
            securityMode: mode,
            newPIN: pin
        )
        try Task.checkCancellation()
        try await authorizeWrite()
        return try await setLocked.execute(true)
    }

    func unlock(
        pin: String,
        vehicleIdentifier: String,
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> BikeLockControlSnapshot? {
        guard await credentialStore.verify(pin: pin, for: vehicleIdentifier) else { return nil }
        try Task.checkCancellation()
        try await authorizeWrite()
        return try await setLocked.execute(false)
    }

    func authenticateAndUnlock(
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> AuthenticationResult {
        guard try await authenticator.authenticate(reason: "Unlock your motorcycle") else {
            return .requiresPIN
        }
        do {
            try Task.checkCancellation()
            try await authorizeWrite()
            return .unlocked(try await setLocked.execute(false))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .writeFailed(error.localizedDescription)
        }
    }

    func setLocked(
        _ target: Bool,
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> BikeLockControlSnapshot {
        try await authorizeWrite()
        return try await setLocked.execute(target)
    }
}
