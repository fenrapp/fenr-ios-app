import BikeDomain
import Foundation

@MainActor
extension BikeLockCardViewModel {
    func checkFirmwareCompatibility() {
        guard !hasAttemptedCompatibilityCheck else { return }
        hasAttemptedCompatibilityCheck = true
        compatibilityTask?.cancel()
        compatibilityTask = Task { [weak self, operationService] in
            for attempt in 1 ... Constants.maximumCompatibilityAttempts {
                do {
                    let compatibility = try await operationService.firmwareCompatibility()
                    guard !Task.isCancelled, let self else { return }
                    compatibilityTask = nil
                    firmware = compatibility.firmware
                    isFirmwareCompatible = compatibility.isCompatible
                    if !compatibility.isCompatible {
                        isLocked = false
                        hasConfirmedLockState = false
                    }
                    capabilityStore.update(.init(
                        vehicleIdentifier: vehicleIdentifier,
                        isAvailable: compatibility.isCompatible
                    ))
                    if compatibility.isCompatible, canPrepareControl {
                        prepare()
                    } else {
                        render()
                    }
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    guard attempt < Constants.maximumCompatibilityAttempts else {
                        guard let self else { return }
                        compatibilityTask = nil
                        render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed))
                        return
                    }
                    do {
                        try await Task.sleep(for: Constants.compatibilityRetryDelay)
                    } catch {
                        return
                    }
                }
            }
        }
    }

    func prepare() {
        guard !hasAttemptedPreparation else { return }
        hasAttemptedPreparation = true
        operationTask?.cancel()
        render(isWorking: true)
        operationTask = Task { [weak self, operationService] in
            guard let self else { return }
            do {
                let snapshot = try await operationService.prepare()
                guard !Task.isCancelled else { return }
                firmware = snapshot.vcuFirmware
                isFirmwareCompatible = true
                isControlPrepared = true
                isLocked = snapshot.isLocked
                hasConfirmedLockState = true
                capabilityStore.update(.init(
                    vehicleIdentifier: vehicleIdentifier,
                    isAvailable: true
                ))
                render()
            } catch {
                guard !Task.isCancelled else { return }
                isControlPrepared = false
                render(error: rideDashboardLocalized(.rideDashboardBikeLockErrorOperationFailed))
            }
        }
    }

    func authenticateAndUnlock() {
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

    func changeLockState(to target: Bool) {
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

    func apply(_ snapshot: BikeLockControlSnapshot) {
        firmware = snapshot.vcuFirmware
        isFirmwareCompatible = true
        isControlPrepared = true
        isLocked = snapshot.isLocked
        hasConfirmedLockState = true
        render(sheetUpdate: .dismiss)
    }

    var authorizeBikeLockWrite: @MainActor @Sendable () throws -> Void {
        { [weak self] in
            guard let self else { throw CancellationError() }
            guard isVehicleStationary, isReceivingTelemetry else {
                throw BikeLockCardOperationError.vehicleMustBeStationary
            }
        }
    }

    func invalidateControlPreparation() {
        guard isReceivingTelemetry || isControlPrepared || hasAttemptedPreparation else { return }
        operationTask?.cancel()
        operationTask = nil
        isReceivingTelemetry = false
        canPrepareControl = false
        isVehicleStationary = false
        isControlPrepared = false
        hasAttemptedPreparation = false
    }

    func suspendControlPreparation() {
        operationTask?.cancel()
        operationTask = nil
        compatibilityTask?.cancel()
        compatibilityTask = nil
        isReceivingTelemetry = false
        canPrepareControl = false
        isVehicleStationary = false
        isControlPrepared = false
        hasAttemptedCompatibilityCheck = false
        hasAttemptedPreparation = false
        render(sheetUpdate: .dismiss)
    }

    func invalidateVehicle(clearsCapability: Bool = true) {
        operationTask?.cancel()
        operationTask = nil
        vehicleIdentifier = nil
        settings = .init()
        isLocked = false
        invalidateControlPreparation()
        resetCompatibility()
        if clearsCapability {
            capabilityStore.update(.init())
        }
        render(sheetUpdate: .dismiss)
    }

    func resetCompatibility() {
        compatibilityTask?.cancel()
        compatibilityTask = nil
        firmware = nil
        isFirmwareCompatible = false
        isControlPrepared = false
        isLocked = false
        hasConfirmedLockState = false
        hasAttemptedCompatibilityCheck = false
        hasAttemptedPreparation = false
    }

    func render(
        isWorking: Bool = false,
        error: String? = nil,
        sheetUpdate: BikeLockSheetUpdate = .preserve
    ) {
        viewState = mapper.map(.init(
            firmware: firmware,
            isFirmwareCompatible: isFirmwareCompatible,
            isControlPrepared: isControlPrepared,
            isLocked: isLocked,
            hasConfirmedLockState: hasConfirmedLockState,
            isWorking: isWorking,
            isReceivingTelemetry: isReceivingTelemetry,
            isVehicleStationary: isVehicleStationary,
            securityMode: settings.securityMode,
            error: error,
            sheetUpdate: sheetUpdate,
            currentSheet: viewState.sheet
        ))
    }

    private enum Constants {
        static let maximumCompatibilityAttempts = 3
        static let compatibilityRetryDelay = Duration.milliseconds(250)
    }
}
