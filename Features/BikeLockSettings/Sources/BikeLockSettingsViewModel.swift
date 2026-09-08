import BikeDomain
import Foundation
import Observation
import SettingsDomain
import VehicleSession

@MainActor
@Observable
public final class BikeLockSettingsViewModel {
    public private(set) var viewState = BikeLockSettingsViewState()

    private let vehicleSession: any VehicleSessionService
    private let capabilityStore: any BikeLockCapabilityStateStoring
    private let securityService: BikeLockSettingsSecurityService
    private let mapper: BikeLockSettingsViewStateMapper
    @ObservationIgnored private var activeVIN: String?
    @ObservationIgnored private var settings = AppSettings()
    @ObservationIgnored private var capability = BikeLockCapabilityState()
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var capabilityTask: Task<Void, Never>?
    @ObservationIgnored private var operationTask: Task<Void, Never>?
    @ObservationIgnored private var operationGeneration = 0
    @ObservationIgnored private var actionAfterAuthentication: BikeLockSettingsDestination?
    @ObservationIgnored private var isCanonicalTelemetryAvailable = false

    public init(
        vehicleSession: any VehicleSessionService,
        capabilityStore: any BikeLockCapabilityStateStoring,
        securityService: BikeLockSettingsSecurityService,
        mapper: BikeLockSettingsViewStateMapper
    ) {
        self.vehicleSession = vehicleSession
        self.capabilityStore = capabilityStore
        self.securityService = securityService
        self.mapper = mapper
    }

    deinit {
        observationTask?.cancel()
        capabilityTask?.cancel()
        operationTask?.cancel()
    }

    public func start() {
        guard observationTask == nil, capabilityTask == nil else { return }
        capability = capabilityStore.currentState
        render()

        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }

        let capabilityStore = capabilityStore
        capabilityTask = Task { [weak self] in
            for await capability in capabilityStore.observe() {
                guard !Task.isCancelled else { return }
                self?.receive(capability)
            }
        }
    }

    public func stopAndWait() async {
        let tasks = [
            observationTask, capabilityTask, operationTask
        ]
        tasks.forEach { $0?.cancel() }
        stop()
        for task in tasks { await task?.value }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        capabilityTask?.cancel()
        capabilityTask = nil
        invalidateOperation()
        activeVIN = nil
        settings = AppSettings()
        capability = BikeLockCapabilityState()
        isCanonicalTelemetryAvailable = false
        render(destination: .set(nil), error: .set(nil), isWorking: false)
    }

    public func changeProtection() {
        guard canBeginAction else { return }
        authenticateIfNeeded(then: .chooseProtection)
    }

    public func changePIN() {
        guard canBeginAction, currentMode.requiresPIN else { return }
        authenticateIfNeeded(then: .changePIN)
    }

    public func submitCurrentPIN(_ pin: String) {
        guard canBeginAction,
              viewState.destination == .verifyCurrentPIN,
              let vin = activeVIN,
              let destination = actionAfterAuthentication else { return }
        let securityService = securityService
        runOperation(for: vin) {
            try await securityService.verify(pin: pin, for: vin)
            return { viewModel in
                viewModel.actionAfterAuthentication = nil
                viewModel.render(destination: .set(destination), error: .set(nil), isWorking: false)
            }
        }
    }

    public func select(_ optionID: BikeLockProtectionOptionID) {
        guard canBeginAction,
              viewState.destination == .chooseProtection,
              let option = viewState.protectionOptions.first(where: { $0.id == optionID }),
              !option.isSelected,
              !option.requiresPINSetup else { return }
        update(mode: mapper.securityMode(for: optionID), newPIN: nil)
    }

    public func saveNewPIN(
        _ pin: String,
        confirmation: String,
        optionID: BikeLockProtectionOptionID? = nil
    ) {
        guard canBeginAction else { return }
        let mode: BikeLockSecurityMode
        if viewState.destination == .changePIN, optionID == nil, currentMode.requiresPIN {
            mode = currentMode
        } else if viewState.destination == .chooseProtection,
                  let optionID,
                  let option = viewState.protectionOptions.first(where: { $0.id == optionID }),
                  option.requiresPINSetup {
            mode = mapper.securityMode(for: optionID)
        } else {
            return
        }
        guard pin == confirmation else {
            render(error: .set(BikeLockSettingsError.pinMismatch.localizedDescription))
            return
        }
        update(mode: mode, newPIN: pin)
    }

    public func dismissDestination() {
        guard viewState.isAvailable else { return }
        invalidateOperation()
        render(destination: .set(nil), error: .set(nil), isWorking: false)
    }
}

private extension BikeLockSettingsViewModel {
    typealias OperationCompletion = @MainActor @Sendable (BikeLockSettingsViewModel) -> Void

    var currentMode: BikeLockSecurityMode {
        settings.bikeLockSettings(forVIN: activeVIN).securityMode
    }

    var canBeginAction: Bool {
        viewState.isAvailable && isCanonicalTelemetryAvailable && operationTask == nil
    }

    func receive(_ snapshot: VehicleSessionSnapshot) {
        let previousVIN = activeVIN
        activeVIN = snapshot.profile?.vin
        settings = snapshot.settings
        isCanonicalTelemetryAvailable = snapshot.isCanonicalTelemetryAvailable
        if previousVIN != nil, previousVIN != activeVIN {
            invalidateOperation()
        }
        if !isCurrentContextAvailable {
            invalidateOperation()
        }
        render()
    }

    func receive(_ newCapability: BikeLockCapabilityState) {
        capability = newCapability
        if !isCurrentContextAvailable {
            invalidateOperation()
        }
        render()
    }

    var isCurrentContextAvailable: Bool {
        activeVIN != nil
            && capability.isAvailable
            && capability.vehicleIdentifier == activeVIN
            && isCanonicalTelemetryAvailable
    }

    func authenticateIfNeeded(then destination: BikeLockSettingsDestination) {
        guard currentMode.requiresPIN else {
            render(destination: .set(destination), error: .set(nil), isWorking: false)
            return
        }
        actionAfterAuthentication = destination
        if currentMode == .pin {
            render(destination: .set(.verifyCurrentPIN), error: .set(nil), isWorking: false)
            return
        }
        guard let vin = activeVIN else { return }
        let securityService = securityService
        runOperation(for: vin) {
            let authenticated = try await securityService.authenticate(for: vin)
            return { viewModel in
                if authenticated {
                    viewModel.actionAfterAuthentication = nil
                    viewModel.render(destination: .set(destination), error: .set(nil), isWorking: false)
                } else {
                    viewModel.render(
                        destination: .set(.verifyCurrentPIN),
                        error: .set(nil),
                        isWorking: false
                    )
                }
            }
        }
    }

    func update(mode: BikeLockSecurityMode, newPIN: String?) {
        guard let vin = activeVIN else { return }
        guard !mode.requiresPIN || currentMode.requiresPIN || newPIN != nil else { return }
        let securityService = securityService
        runOperation(for: vin) {
            try await securityService.update(
                vehicleIdentifier: vin,
                mode: mode,
                newPIN: newPIN
            )
            return { viewModel in
                viewModel.settings.setBikeLockSettings(.init(securityMode: mode), forVIN: vin)
                viewModel.actionAfterAuthentication = nil
                viewModel.render(destination: .set(nil), error: .set(nil), isWorking: false)
            }
        }
    }

    func runOperation(
        for vin: String,
        _ operation: @escaping @Sendable () async throws -> OperationCompletion
    ) {
        guard operationTask == nil, isCurrentContextAvailable, activeVIN == vin else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        render(error: .set(nil), isWorking: true)
        operationTask = Task { [weak self] in
            do {
                let completion = try await operation()
                guard !Task.isCancelled else { throw CancellationError() }
                self?.completeOperation(completion, generation: generation, vin: vin)
            } catch is CancellationError {
                self?.completeCancellation(generation: generation, vin: vin)
            } catch {
                self?.completeOperation(
                    { viewModel in
                        viewModel.render(
                            error: .set(viewModel.presentationMessage(for: error)),
                            isWorking: false
                        )
                    },
                    generation: generation,
                    vin: vin
                )
            }
        }
    }

    func completeOperation(
        _ completion: OperationCompletion,
        generation: Int,
        vin: String
    ) {
        guard generation == operationGeneration,
              activeVIN == vin,
              isCurrentContextAvailable else { return }
        operationTask = nil
        completion(self)
    }

    func completeCancellation(generation: Int, vin: String) {
        guard generation == operationGeneration,
              activeVIN == vin,
              isCurrentContextAvailable else { return }
        operationTask = nil
        render(error: .set(nil), isWorking: false)
    }

    func invalidateOperation() {
        operationGeneration &+= 1
        operationTask?.cancel()
        operationTask = nil
        actionAfterAuthentication = nil
        render(destination: .set(nil), error: .set(nil), isWorking: false)
    }

    func presentationMessage(for error: Error) -> String {
        if let settingsError = error as? BikeLockSettingsError {
            return settingsError.localizedDescription
        }
        return String(localized: .bikeLockSettingsGenericError)
    }

    func render(
        destination: BikeLockSettingsViewUpdate<BikeLockSettingsDestination?> = .preserve,
        error: BikeLockSettingsViewUpdate<String?> = .preserve,
        isWorking: Bool? = nil
    ) {
        viewState = mapper.map(
            settings: settings,
            vehicleIdentifier: activeVIN,
            capability: capability,
            isWorking: isWorking ?? viewState.isWorking,
            errorMessage: error.resolve(previous: viewState.errorMessage),
            destination: destination.resolve(previous: viewState.destination),
            isCanonicalTelemetryAvailable: isCanonicalTelemetryAvailable
        )
    }
}
