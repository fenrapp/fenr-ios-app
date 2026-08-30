import BikeDomain
import Combine
import Foundation
import SettingsDomain
import VehicleSession

@MainActor
public final class BikeLockSettingsViewModel: ObservableObject {
    @Published public private(set) var viewState = BikeLockSettingsViewState()

    private let vehicleSession: any VehicleSessionService
    private let capabilityStore: any BikeLockCapabilityStateStoring
    private let credentialStore: any BikeLockCredentialStoring
    private let authenticator: any BikeLockAuthenticating
    private let updateSecurity: UpdateBikeLockSecurityUseCase
    private var snapshot = VehicleSessionSnapshot()
    private var capability = BikeLockCapabilityState()
    private var observationTask: Task<Void, Never>?
    private var capabilityTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var actionAfterAuthentication: BikeLockSettingsDestination?

    public init(
        vehicleSession: any VehicleSessionService,
        capabilityStore: any BikeLockCapabilityStateStoring,
        credentialStore: any BikeLockCredentialStoring,
        authenticator: any BikeLockAuthenticating,
        updateSecurity: UpdateBikeLockSecurityUseCase
    ) {
        self.vehicleSession = vehicleSession
        self.capabilityStore = capabilityStore
        self.credentialStore = credentialStore
        self.authenticator = authenticator
        self.updateSecurity = updateSecurity
    }

    deinit {
        observationTask?.cancel()
        capabilityTask?.cancel()
        operationTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        capability = capabilityStore.currentState
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await value in stream {
                guard !Task.isCancelled else { return }
                self?.snapshot = value
                self?.render()
            }
        }
        let capabilityStore = capabilityStore
        capabilityTask = Task { [weak self] in
            for await value in capabilityStore.observe() {
                guard !Task.isCancelled else { return }
                self?.capability = value
                self?.render()
            }
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        capabilityTask?.cancel()
        capabilityTask = nil
        operationTask?.cancel()
        operationTask = nil
        actionAfterAuthentication = nil
        render(destination: .set(nil), isWorking: false)
    }

    public func changeProtection() { authenticateIfNeeded(then: .chooseProtection) }
    public func changePIN() { authenticateIfNeeded(then: .changePIN) }

    public func submitCurrentPIN(_ pin: String) {
        guard let vin = activeVIN, let destination = actionAfterAuthentication else { return }
        runOperation {
            guard await self.credentialStore.verify(pin: pin, for: vin) else {
                throw BikeLockSettingsError.incorrectPIN
            }
            self.actionAfterAuthentication = nil
            self.render(destination: .set(destination), isWorking: false)
        }
    }

    public func select(_ mode: BikeLockSecurityMode) {
        guard mode != .notConfigured else { return }
        if mode.requiresPIN, !currentMode.requiresPIN {
            render(destination: .set(.createPIN(mode)), isWorking: false)
        } else {
            update(mode: mode, newPIN: nil)
        }
    }

    public func saveNewPIN(_ pin: String, confirmation: String, mode: BikeLockSecurityMode? = nil) {
        guard pin == confirmation else {
            render(error: BikeLockSettingsError.pinMismatch.localizedDescription)
            return
        }
        update(mode: mode ?? currentMode, newPIN: pin)
    }

    public func dismissDestination() {
        actionAfterAuthentication = nil
        render(destination: .set(nil), isWorking: false)
    }
}

private extension BikeLockSettingsViewModel {
    var activeVIN: String? { snapshot.profile?.vin }
    var currentMode: BikeLockSecurityMode { snapshot.settings.bikeLockSettings(forVIN: activeVIN).securityMode }

    func authenticateIfNeeded(then destination: BikeLockSettingsDestination) {
        guard currentMode.requiresPIN else {
            render(destination: .set(destination), isWorking: false)
            return
        }
        actionAfterAuthentication = destination
        if currentMode == .pin {
            render(destination: .set(.verifyCurrentPIN), isWorking: false)
            return
        }
        guard let vin = activeVIN else { return }
        runOperation {
            guard await self.credentialStore.containsPIN(for: vin) else {
                throw BikeLockSettingsError.missingCredential
            }
            let authenticated = (try? await self.authenticator.authenticate(
                reason: "Change Bike Lock protection"
            )) ?? false
            if authenticated {
                self.actionAfterAuthentication = nil
                self.render(destination: .set(destination), isWorking: false)
            } else {
                self.render(destination: .set(.verifyCurrentPIN), isWorking: false)
            }
        }
    }

    func update(mode: BikeLockSecurityMode, newPIN: String?) {
        guard let vin = activeVIN else { return }
        runOperation {
            try await self.updateSecurity.execute(vehicleIdentifier: vin, securityMode: mode, newPIN: newPIN)
            var updated = self.snapshot.settings
            updated.setBikeLockSettings(.init(securityMode: mode), forVIN: vin)
            self.snapshot = .init(
                telemetry: self.snapshot.telemetry,
                connection: self.snapshot.connection,
                settings: updated,
                profile: self.snapshot.profile,
                resolvedSpeedKilometersPerHour: self.snapshot.resolvedSpeedKilometersPerHour,
                speedSource: self.snapshot.speedSource,
                isGPSAvailable: self.snapshot.isGPSAvailable,
                batteryHealth: self.snapshot.batteryHealth,
                batteryHealthMonitoringState: self.snapshot.batteryHealthMonitoringState,
                motion: self.snapshot.motion,
                hasReceivedSettings: self.snapshot.hasReceivedSettings,
                hasReceivedProfile: self.snapshot.hasReceivedProfile
            )
            self.render(destination: .set(nil), isWorking: false)
        }
    }

    func runOperation(_ operation: @escaping @MainActor () async throws -> Void) {
        guard operationTask == nil else { return }
        render(isWorking: true)
        operationTask = Task { [weak self] in
            do {
                try await operation()
                guard !Task.isCancelled else { return }
                self?.operationTask = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.operationTask = nil
                self?.render(error: error.localizedDescription, isWorking: false)
            }
        }
    }

    func render(
        destination: DestinationUpdate = .preserve,
        error: String? = nil,
        isWorking: Bool? = nil
    ) {
        let vin = activeVIN
        let available = vin != nil && capability.isAvailable && capability.vehicleIdentifier == vin
        viewState = .init(
            isAvailable: available,
            currentMode: currentMode,
            isWorking: isWorking ?? viewState.isWorking,
            errorMessage: error,
            destination: available ? destination.resolve(previous: viewState.destination) : nil
        )
    }
}

private enum DestinationUpdate {
    case preserve
    case set(BikeLockSettingsDestination?)

    func resolve(previous: BikeLockSettingsDestination?) -> BikeLockSettingsDestination? {
        switch self {
        case .preserve: previous
        case .set(let destination): destination
        }
    }
}

private enum BikeLockSettingsError: LocalizedError {
    case incorrectPIN
    case missingCredential
    case pinMismatch

    var errorDescription: String? {
        switch self {
        case .incorrectPIN: "Incorrect PIN"
        case .missingCredential: "The saved PIN is unavailable."
        case .pinMismatch: "The PINs do not match."
        }
    }
}
