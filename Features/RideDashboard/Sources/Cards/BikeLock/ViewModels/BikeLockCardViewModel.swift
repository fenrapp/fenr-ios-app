import BikeDomain
import Combine
import Foundation
import SettingsDomain
import VehicleSession
@MainActor
public final class BikeLockCardViewModel: ObservableObject {
    @Published public internal(set) var viewState = BikeLockCardViewState()
    public let securityOptions: [BikeLockSecurityOptionViewData]
    let operationService: BikeLockCardOperationService
    let vehicleSession: any VehicleSessionService
    let capabilityStore: any BikeLockCapabilityStateStoring
    let mapper: BikeLockCardViewStateMapper
    let vehicleContextMapper: BikeLockCardVehicleContextMapper
    var observationTask: Task<Void, Never>?
    var compatibilityTask: Task<Void, Never>?
    var operationTask: Task<Void, Never>?
    var vehicleIdentifier: String?
    var settings = BikeLockSettings()
    var isLocked = false
    var hasConfirmedLockState = false
    var firmware: String?
    var isFirmwareCompatible = false
    var isControlPrepared = false
    var canPrepareControl = false
    var isVehicleStationary = false
    var hasAttemptedCompatibilityCheck = false
    var hasAttemptedPreparation = false
    var isReceivingTelemetry = false
    var operationError: String?

    public init(
        operationService: BikeLockCardOperationService,
        vehicleSession: any VehicleSessionService,
        capabilityStore: any BikeLockCapabilityStateStoring,
        mapper: BikeLockCardViewStateMapper,
        vehicleContextMapper: BikeLockCardVehicleContextMapper,
        securityOptionProvider: BikeLockSecurityOptionProvider
    ) {
        self.operationService = operationService
        self.vehicleSession = vehicleSession
        self.capabilityStore = capabilityStore
        self.mapper = mapper
        self.vehicleContextMapper = vehicleContextMapper
        securityOptions = securityOptionProvider.options
    }
    deinit {
        observationTask?.cancel()
        compatibilityTask?.cancel()
        operationTask?.cancel()
    }
}
public extension BikeLockCardViewModel {
    func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, vehicleSession] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled, let self else { return }
                let context = vehicleContextMapper.map(snapshot)
                guard let vin = context.vehicleIdentifier else {
                    invalidateVehicle()
                    continue
                }
                if !context.isReceivingTelemetry {
                    suspendControlPreparation()
                    continue
                }
                if !isReceivingTelemetry {
                    invalidateControlPreparation()
                }
                isReceivingTelemetry = true
                canPrepareControl = context.canPrepareNoOp
                isVehicleStationary = context.canPerformLockWrite
                if !context.canPrepareNoOp, !isControlPrepared, hasAttemptedPreparation {
                    operationTask?.cancel()
                    operationTask = nil
                    hasAttemptedPreparation = false
                    render(isWorking: false)
                }
                if vehicleIdentifier != vin {
                    operationError = nil
                    operationTask?.cancel()
                    operationTask = nil
                    vehicleIdentifier = vin
                    settings = context.settings
                    resetCompatibility()
                    capabilityStore.update(.init(vehicleIdentifier: vin))
                    render(isWorking: false, sheetUpdate: .dismiss)
                } else {
                    settings = context.settings
                }
                if !hasAttemptedCompatibilityCheck {
                    checkFirmwareCompatibility()
                } else if isFirmwareCompatible,
                          !isControlPrepared,
                          !hasAttemptedPreparation,
                          context.canPrepareNoOp {
                    prepare()
                } else {
                    render()
                }
            }
        }
    }
    func stop() {
        observationTask?.cancel()
        observationTask = nil
        invalidateVehicle(clearsCapability: false)
    }
    func suspend() {
        observationTask?.cancel()
        observationTask = nil
        suspendControlPreparation()
    }
    func performPrimaryAction() {
        guard viewState.isActionEnabled else { return }
        operationError = nil
        guard isVehicleStationary else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorStopBike))
            return
        }
        if !isLocked {
            guard settings.securityMode.isConfigured else {
                render(sheetUpdate: .present(.setup))
                return
            }
            changeLockState(to: true)
            return
        }
        switch settings.securityMode {
        case .notConfigured:
            changeLockState(to: false)
        case .withoutPIN:
            changeLockState(to: false)
        case .pin:
            render(sheetUpdate: .present(.enterPIN))
        case .pinAndFaceID:
            authenticateAndUnlock()
        }
    }
    func configure(securityOptionID: String, pin: String) {
        guard !viewState.isWorking else { return }
        guard isReceivingTelemetry, isVehicleStationary else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorStopBike))
            return
        }
        operationError = nil
        guard let mode = BikeLockSecurityMode(rawValue: securityOptionID), mode.isConfigured,
              let vehicleIdentifier else { return }
        guard !mode.requiresPIN || UpdateBikeLockSecurityUseCase.isValidPIN(pin) else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorEnterPIN), sheetUpdate: .present(.setup))
            return
        }
        let normalizedPIN = mode.requiresPIN ? pin : ""
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                let snapshot = try await operationService.configure(
                    vehicleIdentifier: vehicleIdentifier,
                    mode: mode,
                    pin: mode.requiresPIN ? normalizedPIN : nil,
                    authorizeWrite: authorizeBikeLockWrite
                )
                guard !Task.isCancelled else { return }
                settings = .init(securityMode: mode)
                apply(snapshot)
            } catch {
                guard !Task.isCancelled else { return }
                render(
                    error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed),
                    sheetUpdate: .present(.setup)
                )
            }
        }
    }
    func submitPIN(_ pin: String) {
        guard !viewState.isWorking else { return }
        guard isReceivingTelemetry, isVehicleStationary else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorStopBike))
            return
        }
        operationError = nil
        guard let vehicleIdentifier, UpdateBikeLockSecurityUseCase.isValidPIN(pin) else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorEnterPIN), sheetUpdate: .present(.enterPIN))
            return
        }
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                let snapshot = try await operationService.unlock(
                    pin: pin,
                    vehicleIdentifier: vehicleIdentifier,
                    authorizeWrite: authorizeBikeLockWrite
                )
                guard !Task.isCancelled else { return }
                guard let snapshot else {
                    render(
                        error: rideDashboardLocalized(.rideDashboardBikeLockErrorIncorrectPIN),
                        sheetUpdate: .present(.enterPIN)
                    )
                    return
                }
                apply(snapshot)
            } catch {
                guard !Task.isCancelled else { return }
                render(
                    error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed),
                    sheetUpdate: .present(.enterPIN)
                )
            }
        }
    }
    func dismissSheet() {
        guard !viewState.isWorking else { return }
        operationError = nil
        render(sheetUpdate: .dismiss)
    }
}
#if DEBUG
extension BikeLockCardViewModel {
    var isObservingForTesting: Bool { observationTask != nil }

    func setPreviewState(_ state: BikeLockCardViewState) {
        viewState = state
    }
}
#endif
