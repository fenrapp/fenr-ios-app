import BikeDomain
import SettingsDomain

public struct BikeLockCardOperationService: Sendable {
    enum AuthenticationResult: Sendable {
        case unlocked(BikeLockControlSnapshot)
        case requiresPIN
        case writeFailed
    }

    private let readFirmwareCompatibility: ReadBikeLockFirmwareCompatibilityUseCase
    private let prepareControl: PrepareBikeLockControlUseCase
    private let setLocked: SetBikeLockedUseCase
    private let updateSecurity: UpdateBikeLockSecurityUseCase
    private let credentialStore: any BikeLockCredentialStoring
    private let authenticator: any BikeLockAuthenticating

    public init(
        readFirmwareCompatibility: ReadBikeLockFirmwareCompatibilityUseCase,
        prepareControl: PrepareBikeLockControlUseCase,
        setLocked: SetBikeLockedUseCase,
        updateSecurity: UpdateBikeLockSecurityUseCase,
        credentialStore: any BikeLockCredentialStoring,
        authenticator: any BikeLockAuthenticating
    ) {
        self.readFirmwareCompatibility = readFirmwareCompatibility
        self.prepareControl = prepareControl
        self.setLocked = setLocked
        self.updateSecurity = updateSecurity
        self.credentialStore = credentialStore
        self.authenticator = authenticator
    }

    func firmwareCompatibility() async throws -> BikeLockFirmwareCompatibility {
        try await readFirmwareCompatibility.execute()
    }

    func prepare() async throws -> BikeLockControlSnapshot {
        try validated(try await prepareControl.execute())
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
        return try validated(try await setLocked.execute(true))
    }

    func unlock(
        pin: String,
        vehicleIdentifier: String,
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> BikeLockControlSnapshot? {
        guard await credentialStore.verify(pin: pin, for: vehicleIdentifier) else { return nil }
        try Task.checkCancellation()
        try await authorizeWrite()
        return try validated(try await setLocked.execute(false))
    }

    func authenticateAndUnlock(
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> AuthenticationResult {
        guard try await authenticator.authenticate(
            reason: rideDashboardLocalized(.rideDashboardBikeLockAuthenticationReason)
        ) else {
            return .requiresPIN
        }
        do {
            try Task.checkCancellation()
            try await authorizeWrite()
            return .unlocked(try validated(try await setLocked.execute(false)))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .writeFailed
        }
    }

    func setLocked(
        _ target: Bool,
        authorizeWrite: @MainActor @Sendable () throws -> Void
    ) async throws -> BikeLockControlSnapshot {
        try await authorizeWrite()
        return try validated(try await setLocked.execute(target))
    }

    private func validated(_ snapshot: BikeLockControlSnapshot) throws -> BikeLockControlSnapshot {
        guard snapshot.didPassNoOpWrite else {
            throw BikeLockCardOperationError.noOpValidationFailed
        }
        return snapshot
    }
}
