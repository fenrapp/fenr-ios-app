import BikeDomain
import Combine
import Foundation
import SettingsDomain
import VehicleSession
@MainActor
public final class BikeLockCardViewModel: ObservableObject {
    @Published public private(set) var viewState = BikeLockCardViewState()
    public let securityOptions: [BikeLockSecurityOptionViewData]
    private let operationService: BikeLockCardOperationService
    private let vehicleSession: any VehicleSessionService
    private let capabilityStore: any BikeLockCapabilityStateStoring
    private let mapper: BikeLockCardViewStateMapper
    private let vehicleContextMapper: BikeLockCardVehicleContextMapper
    private let allowsExperimentalControl: Bool
    private var observationTask: Task<Void, Never>?
    private var operationTask: Task<Void, Never>?
    private var vehicleIdentifier: String?
    private var settings = BikeLockSettings()
    private var isLocked = false
    private var firmware: String?
    private var isVehicleStationary = false
    private var hasAttemptedPreparation = false
    private var isReceivingTelemetry = false

    public init(
        operationService: BikeLockCardOperationService,
        vehicleSession: any VehicleSessionService,
        capabilityStore: any BikeLockCapabilityStateStoring,
        mapper: BikeLockCardViewStateMapper,
        vehicleContextMapper: BikeLockCardVehicleContextMapper,
        securityOptionProvider: BikeLockSecurityOptionProvider,
        allowsExperimentalControl: Bool
    ) {
        self.operationService = operationService
        self.vehicleSession = vehicleSession
        self.capabilityStore = capabilityStore
        self.mapper = mapper
        self.vehicleContextMapper = vehicleContextMapper
        securityOptions = securityOptionProvider.options
        self.allowsExperimentalControl = allowsExperimentalControl
    }
    deinit {
        observationTask?.cancel()
        operationTask?.cancel()
    }
}
public extension BikeLockCardViewModel {
    func start() {
        guard allowsExperimentalControl else { return }
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
                isVehicleStationary = context.isStationary
                if vehicleIdentifier != vin {
                    operationTask?.cancel()
                    operationTask = nil
                    vehicleIdentifier = vin
                    settings = context.settings
                    firmware = nil
                    hasAttemptedPreparation = false
                    capabilityStore.update(.init(vehicleIdentifier: vin))
                    if isVehicleStationary {
                        prepare()
                    } else {
                        render()
                    }
                } else {
                    settings = context.settings
                    if firmware == nil, !hasAttemptedPreparation, isVehicleStationary {
                        prepare()
                    } else {
                        render()
                    }
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
        guard isReceivingTelemetry, isVehicleStationary else { return }
        guard let mode = BikeLockSecurityMode(rawValue: securityOptionID), mode.isConfigured,
              let vehicleIdentifier else { return }
        guard !mode.requiresPIN || Self.isValidPIN(pin) else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorEnterPIN), sheetUpdate: .present(.setup))
            return
        }
        let normalizedPIN = mode.requiresPIN ? pin : ""
        operationTask?.cancel()
        render(isWorking: true, sheetUpdate: .dismiss)
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
        guard isReceivingTelemetry, isVehicleStationary else { return }
        guard let vehicleIdentifier, Self.isValidPIN(pin) else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorEnterPIN), sheetUpdate: .present(.enterPIN))
            return
        }
        operationTask?.cancel()
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                guard let snapshot = try await operationService.unlock(
                    pin: pin,
                    vehicleIdentifier: vehicleIdentifier,
                    authorizeWrite: authorizeBikeLockWrite
                ) else {
                    render(
                        error: rideDashboardLocalized(.rideDashboardBikeLockErrorIncorrectPIN),
                        sheetUpdate: .present(.enterPIN)
                    )
                    return
                }
                guard !Task.isCancelled else { return }
                apply(snapshot)
            } catch {
                guard !Task.isCancelled else { return }
                render(
                    error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed),
                    sheetUpdate: .dismiss
                )
            }
        }
    }
    func dismissSheet() {
        render(sheetUpdate: .dismiss)
    }
}
private extension BikeLockCardViewModel {
    private func prepare() {
        guard !hasAttemptedPreparation else { return }
        hasAttemptedPreparation = true
        operationTask?.cancel()
        firmware = nil
        render(isWorking: true)
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                let snapshot = try await operationService.prepare()
                guard !Task.isCancelled else { return }
                firmware = snapshot.vcuFirmware
                isLocked = snapshot.isLocked
                capabilityStore.update(.init(
                    vehicleIdentifier: vehicleIdentifier,
                    isAvailable: true
                ))
                render()
            } catch {
                guard !Task.isCancelled else { return }
                firmware = nil
                capabilityStore.update(.init(vehicleIdentifier: vehicleIdentifier))
                render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed))
            }
        }
    }
    private func authenticateAndUnlock() {
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                let result = try await operationService.authenticateAndUnlock(
                    authorizeWrite: authorizeBikeLockWrite
                )
                guard !Task.isCancelled else { return }
                switch result {
                case .unlocked(let snapshot): apply(snapshot)
                case .requiresPIN: render(sheetUpdate: .present(.enterPIN))
                case .writeFailed:
                    render(
                        error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed),
                        sheetUpdate: .dismiss
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                render(
                    error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed),
                    sheetUpdate: .present(.enterPIN)
                )
            }
        }
    }
    private func changeLockState(to target: Bool) {
        guard isVehicleStationary else {
            render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorStopBike))
            return
        }
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                let snapshot = try await operationService.setLocked(
                    target,
                    authorizeWrite: authorizeBikeLockWrite
                )
                guard !Task.isCancelled else { return }
                apply(snapshot)
            } catch {
                guard !Task.isCancelled else { return }
                render(
                    error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed),
                    sheetUpdate: .dismiss
                )
            }
        }
    }
    private func apply(_ snapshot: BikeLockControlSnapshot) {
        firmware = snapshot.vcuFirmware
        isLocked = snapshot.isLocked
        render(sheetUpdate: .dismiss)
    }
    private var authorizeBikeLockWrite: @MainActor @Sendable () throws -> Void {
        { [weak self] in
            guard let self else { throw CancellationError() }
            guard isVehicleStationary, isReceivingTelemetry else {
                throw BikeLockCardOperationError.vehicleMustBeStationary
            }
        }
    }
    private func invalidateControlPreparation() {
        guard isReceivingTelemetry || firmware != nil || hasAttemptedPreparation else { return }
        operationTask?.cancel()
        operationTask = nil
        isReceivingTelemetry = false
        isVehicleStationary = false
        firmware = nil
        hasAttemptedPreparation = false
    }
    private func suspendControlPreparation() {
        operationTask?.cancel()
        operationTask = nil
        isReceivingTelemetry = false
        isVehicleStationary = false
        hasAttemptedPreparation = false
        render(sheetUpdate: .dismiss)
    }
    private func invalidateVehicle(clearsCapability: Bool = true) {
        operationTask?.cancel()
        operationTask = nil
        vehicleIdentifier = nil
        settings = .init()
        isLocked = false
        invalidateControlPreparation()
        if clearsCapability {
            capabilityStore.update(.init())
        }
        render(sheetUpdate: .dismiss)
    }
}
extension BikeLockCardViewModel {
    private func render(
        isWorking: Bool = false,
        error: String? = nil,
        sheetUpdate: BikeLockSheetUpdate = .preserve
    ) {
        viewState = mapper.map(.init(
            firmware: firmware,
            isLocked: isLocked,
            isWorking: isWorking,
            isReceivingTelemetry: isReceivingTelemetry,
            isVehicleStationary: isVehicleStationary,
            securityMode: settings.securityMode,
            error: error,
            sheetUpdate: sheetUpdate,
            currentSheet: viewState.sheet
        ))
    }

    private static func isValidPIN(_ pin: String) -> Bool {
        pin.count == 6 && pin.utf8.allSatisfy { (48 ... 57).contains($0) }
    }

#if DEBUG
    var isObservingForTesting: Bool { observationTask != nil }

    func setPreviewState(_ state: BikeLockCardViewState) {
        viewState = state
    }
#endif
}
