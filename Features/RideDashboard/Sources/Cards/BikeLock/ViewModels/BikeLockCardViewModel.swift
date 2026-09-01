import BikeDomain
import Combine
import Foundation
import SettingsDomain
import VehicleSession

@MainActor
public final class BikeLockCardViewModel: ObservableObject {
    @Published public private(set) var viewState = BikeLockCardViewState()

    public let securityOptions: [BikeLockSecurityOptionViewData] = [
        .init(
            id: BikeLockSecurityMode.pinAndFaceID.rawValue,
            title: "PIN + Face ID",
            detail: "Use Face ID first, with your PIN as a fallback.",
            requiresPIN: true
        ),
        .init(
            id: BikeLockSecurityMode.pin.rawValue,
            title: "PIN",
            detail: "Enter a 6-digit PIN whenever you unlock.",
            requiresPIN: true
        ),
        .init(
            id: BikeLockSecurityMode.withoutPIN.rawValue,
            title: "No PIN",
            detail: "Lock and unlock immediately from the card.",
            requiresPIN: false
        )
    ]

    private let prepareControl: PrepareBikeLockControlUseCase
    private let setLocked: SetBikeLockedUseCase
    private let updateSecurity: UpdateBikeLockSecurityUseCase
    private let vehicleSession: any VehicleSessionService
    private let credentialStore: any BikeLockCredentialStoring
    private let authenticator: any BikeLockAuthenticating
    private let capabilityStore: any BikeLockCapabilityStateStoring
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
        prepareControl: PrepareBikeLockControlUseCase,
        setLocked: SetBikeLockedUseCase,
        updateSecurity: UpdateBikeLockSecurityUseCase,
        vehicleSession: any VehicleSessionService,
        credentialStore: any BikeLockCredentialStoring,
        authenticator: any BikeLockAuthenticating,
        capabilityStore: any BikeLockCapabilityStateStoring,
        allowsExperimentalControl: Bool
    ) {
        self.prepareControl = prepareControl
        self.setLocked = setLocked
        self.updateSecurity = updateSecurity
        self.vehicleSession = vehicleSession
        self.credentialStore = credentialStore
        self.authenticator = authenticator
        self.capabilityStore = capabilityStore
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
                guard let vin = snapshot.profile?.vin, !vin.isEmpty else {
                    invalidateVehicle()
                    continue
                }
                let receivesTelemetry = Self.receivesTelemetry(snapshot)
                if !receivesTelemetry {
                    suspendControlPreparation()
                    continue
                }
                if !isReceivingTelemetry {
                    invalidateControlPreparation()
                }
                isReceivingTelemetry = true
                isVehicleStationary = Self.isSafeToOperate(snapshot)
                if vehicleIdentifier != vin {
                    operationTask?.cancel()
                    operationTask = nil
                    vehicleIdentifier = vin
                    settings = snapshot.settings.bikeLockSettings(forVIN: vin)
                    firmware = nil
                    hasAttemptedPreparation = false
                    capabilityStore.update(.init(vehicleIdentifier: vin))
                    if isVehicleStationary {
                        prepare()
                    } else {
                        render()
                    }
                } else {
                    settings = snapshot.settings.bikeLockSettings(forVIN: vin)
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
            render(error: "Stop the motorcycle and disengage the gear before using Bike Lock.")
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
            render(error: "Enter a 6-digit PIN", sheetUpdate: .present(.setup))
            return
        }
        let normalizedPIN = mode.requiresPIN ? pin : ""
        operationTask?.cancel()
        render(isWorking: true, sheetUpdate: .dismiss)
        operationTask = Task { [weak self, updateSecurity] in
            guard let self else { return }
            do {
                try await updateSecurity.execute(
                    vehicleIdentifier: vehicleIdentifier,
                    securityMode: mode,
                    newPIN: mode.requiresPIN ? normalizedPIN : nil
                )
                guard !Task.isCancelled else { return }
                settings = .init(securityMode: mode)
                try await applyLockState(true)
            } catch {
                guard !Task.isCancelled else { return }
                render(error: error.localizedDescription, sheetUpdate: .present(.setup))
            }
        }
    }

    func submitPIN(_ pin: String) {
        guard isReceivingTelemetry, isVehicleStationary else { return }
        guard let vehicleIdentifier, Self.isValidPIN(pin) else {
            render(error: "Enter a 6-digit PIN", sheetUpdate: .present(.enterPIN))
            return
        }
        operationTask?.cancel()
        operationTask = Task { [weak self, credentialStore] in
            guard let self else { return }
            let isValid = await credentialStore.verify(pin: pin, for: vehicleIdentifier)
            guard !Task.isCancelled else { return }
            guard isValid else {
                render(error: "Incorrect PIN", sheetUpdate: .present(.enterPIN))
                return
            }
            do {
                try await applyLockState(false)
            } catch {
                guard !Task.isCancelled else { return }
                render(error: error.localizedDescription, sheetUpdate: .dismiss)
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
        operationTask = Task { [weak self, prepareControl] in
            guard let self else { return }
            do {
                let snapshot = try await prepareControl.execute()
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
                render(error: error.localizedDescription)
            }
        }
    }

    private func authenticateAndUnlock() {
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, authenticator] in
            guard let self else { return }
            let authenticated: Bool
            do {
                authenticated = try await authenticator.authenticate(reason: "Unlock your motorcycle")
            } catch {
                guard !Task.isCancelled else { return }
                render(error: error.localizedDescription, sheetUpdate: .present(.enterPIN))
                return
            }
            guard !Task.isCancelled else { return }
            guard authenticated else {
                render(sheetUpdate: .present(.enterPIN))
                return
            }
            do {
                try await applyLockState(false)
            } catch {
                guard !Task.isCancelled else { return }
                render(error: error.localizedDescription, sheetUpdate: .dismiss)
            }
        }
    }

    private func changeLockState(to target: Bool) {
        guard isVehicleStationary else {
            render(error: "Stop the motorcycle and disengage the gear before using Bike Lock.")
            return
        }
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, setLocked] in
            guard let self else { return }
            do {
                try await applyLockState(target, using: setLocked)
            } catch {
                guard !Task.isCancelled else { return }
                render(error: error.localizedDescription, sheetUpdate: .dismiss)
            }
        }
    }

    private func applyLockState(
        _ target: Bool,
        using useCase: SetBikeLockedUseCase? = nil
    ) async throws {
        guard isVehicleStationary, isReceivingTelemetry else {
            throw BikeLockCardOperationError.vehicleMustBeStationary
        }
        render(isWorking: true)
        let snapshot = try await (useCase ?? setLocked).execute(target)
        guard !Task.isCancelled else { return }
        firmware = snapshot.vcuFirmware
        isLocked = snapshot.isLocked
        render(sheetUpdate: .dismiss)
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
        let isAvailable = firmware != nil
        let status = isLocked ? "Locked" : "Unlocked"
        let actionTitle: String
        actionTitle = isLocked ? "Unlock" : (settings.securityMode.isConfigured ? "Lock" : "Set Up")
        viewState = .init(
            isAvailable: isAvailable,
            isLocked: isLocked,
            isWorking: isWorking,
            isActionEnabled: isAvailable
                && isReceivingTelemetry
                && isVehicleStationary
                && !isWorking,
            isConfigured: settings.securityMode.isConfigured,
            statusText: isAvailable ? status : "Unavailable",
            actionTitle: actionTitle,
            detailText: isAvailable
                ? "VCU PIC \(firmware ?? "")"
                : "Bike Lock requires VCU PIC 1.6.29 or newer.",
            errorText: error,
            sheet: sheetUpdate.resolve(current: viewState.sheet)
        )
    }

    private static func isSafeToOperate(_ snapshot: VehicleSessionSnapshot) -> Bool {
        guard receivesTelemetry(snapshot),
              !snapshot.telemetry.statusFlags.isInGear,
              snapshot.telemetry.runState != .charging,
              let speed = snapshot.resolvedSpeedKilometersPerHour,
              speed.isFinite
        else { return false }
        return abs(speed) < 0.5
    }

    private static func receivesTelemetry(_ snapshot: VehicleSessionSnapshot) -> Bool {
        snapshot.isCanonicalTelemetryAvailable
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
