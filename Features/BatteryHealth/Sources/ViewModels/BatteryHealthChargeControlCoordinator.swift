import BikeDomain
import Foundation

@MainActor
// Power and target commands intentionally share one serialized VCU state machine.
// swiftlint:disable:next type_body_length
final class BatteryHealthChargeControlCoordinator {
    private let useCases: BatteryHealthUseCases
    private let requestRender: @MainActor () -> Void
    private var logger: BatteryHealthChargeControlLogStore
    private let stateUpdater: BatteryHealthChargeControlStateUpdater
    private let taskScheduler: BatteryHealthChargeControlTaskScheduler
    private(set) var state = ChargePowerControlViewState()
    var logLines: [String] { logger.lines }
    private var health = BikeBatteryHealth()
    private var hasAttemptedPrepare = false
    private var isPreparing = false
    private var isWriting = false
    private var pendingPowerConfirmationWatts: Int?
    private var optimisticPowerWatts: Int?
    private var pendingTargetConfirmationPercent: Int?
    private var optimisticTargetPercent: Int?
    private var queuedPowerWatts: Int?
    private var queuedTargetPercent: Int?
    private var isDraggingPower = false
    private var isDraggingTarget = false

    init(
        useCases: BatteryHealthUseCases,
        logger: BatteryHealthChargeControlLogStore,
        stateUpdater: BatteryHealthChargeControlStateUpdater,
        taskScheduler: BatteryHealthChargeControlTaskScheduler,
        requestRender: @escaping @MainActor () -> Void
    ) {
        self.useCases = useCases
        self.logger = logger
        self.stateUpdater = stateUpdater
        self.taskScheduler = taskScheduler
        self.requestRender = requestRender
    }

    func stop() {
        cancelTasks()
        queuedPowerWatts = nil
        queuedTargetPercent = nil
        isDraggingPower = false
        isDraggingTarget = false
    }
    func beginPowerDrag() {
        isDraggingPower = true
        taskScheduler.cancelPowerDebounce()
        queuedPowerWatts = nil
        appendLog("slider drag start; debounce cancelled")
    }
    func setDisplayedPower(watts: Double) {
        state.selectedWatts = watts
        requestRender()
    }
    func endPowerDrag() {
        let finalWatts = normalizedPowerWatts(Int(state.selectedWatts.rounded()))
        isDraggingPower = false
        state.selectedWatts = Double(finalWatts)
        optimisticPowerWatts = finalWatts
        appendLog("slider final value: \(finalWatts) W")
        taskScheduler.schedulePowerDebounce { [weak self] in
            guard let self else { return }
            self.appendLog("debounce fired: \(finalWatts) W")
            await self.writePowerLimit(finalWatts)
        }
    }
    func beginTargetDrag() {
        isDraggingTarget = true
        taskScheduler.cancelTargetDebounce()
        queuedTargetPercent = nil
        appendLog("target slider drag start; debounce cancelled")
    }
    func setDisplayedTarget(percent: Double) {
        state.selectedTargetPercent = percent
        requestRender()
    }

    func endTargetDrag() {
        let finalPercent = normalizedTargetPercent(Int(state.selectedTargetPercent.rounded()))
        isDraggingTarget = false
        state.selectedTargetPercent = Double(finalPercent)
        optimisticTargetPercent = finalPercent
        appendLog("target slider final value: \(finalPercent)%")
        taskScheduler.scheduleTargetDebounce { [weak self] in
            guard let self else { return }
            self.appendLog("target debounce fired: \(finalPercent)%")
            await self.writeTarget(finalPercent)
        }
    }

    func receive(_ health: BikeBatteryHealth) {
        self.health = health
        updateTelemetryState(from: health)
        prepareIfNeeded()
    }

    private func cancelTasks() {
        taskScheduler.cancelAll()
    }

    private func prepareIfNeeded() {
        guard !hasAttemptedPrepare,
              !isPreparing,
              isChargerConnected,
              health.chargingStatus != nil
        else {
            return
        }
        hasAttemptedPrepare = true
        isPreparing = true
        appendLog("prepare started")
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard let chargingStatus = self.health.chargingStatus else {
                    throw BatteryHealthChargePowerError.missingChargerTelemetry
                }
                let snapshot = try await useCases.prepareChargePowerControl.execute(
                    chargingStatus: chargingStatus
                )
                self.stateUpdater.applyPreparation(snapshot, to: &self.state)
                self.appendLog(
                    "firmware VCU PIC: \(snapshot.vcuFirmware ?? "unknown") "
                        + "compatible=\(snapshot.isFirmwareCompatible)"
                )
                self.appendLog(
                    "4005 parse: current=\(snapshot.parsedConfig.chargeCurrentDeciAmperes) dA "
                        + "power=\(snapshot.parsedConfig.chargePowerWatts) W "
                        + "maxSoc=\(snapshot.parsedConfig.maximumStateOfChargeDeciPercent) d%"
                )
                snapshot.logLines.forEach { self.appendLog($0) }
            } catch {
                self.stateUpdater.applyPreparationFailure(error, to: &self.state)
                self.appendLog("prepare failed: \(error)")
            }
            self.isPreparing = false
            self.requestRender()
        }
    }

    private func writePowerLimit(_ watts: Int) async {
        guard state.isEnabled else {
            optimisticPowerWatts = nil
            restorePowerSelection(fallback: state.confirmedWatts ?? watts)
            appendLog("write skipped: control disabled")
            return
        }
        guard isChargerConnected, health.chargingStatus != nil else {
            optimisticPowerWatts = nil
            restorePowerSelection(fallback: state.confirmedWatts ?? watts)
            appendLog("write skipped: charger not connected")
            return
        }
        guard !hasBlockingOperation else {
            queuedPowerWatts = watts
            appendLog("write queued target: \(watts) W")
            return
        }
        if state.confirmedWatts == watts {
            optimisticPowerWatts = nil
            restorePowerSelection(fallback: watts)
            appendLog("write skipped: \(watts) W already confirmed")
            return
        }
        isWriting = true
        state.status = "Writing \(watts) W"
        appendLog("write sent target: \(watts) W")
        requestRender()
        do {
            let snapshot = try await useCases.setChargePowerLimit.execute(watts: watts)
            snapshot.logLines.forEach { appendLog($0) }
            pendingPowerConfirmationWatts = watts
            state.status = "Confirming \(watts) W"
            schedulePowerConfirmationTimeout(watts: watts)
        } catch {
            optimisticPowerWatts = nil
            restorePowerSelection(fallback: state.confirmedWatts ?? watts)
            state.status = "Write failed"
            state.error = String(describing: error)
            appendLog("write failed: \(error)")
        }
        finishWrite()
    }

    private func writeTarget(_ percent: Int) async {
        guard state.isEnabled else {
            optimisticTargetPercent = nil
            restoreTargetSelection(fallback: state.confirmedTargetPercent ?? percent)
            appendLog("target write skipped: control disabled")
            return
        }
        guard isChargerConnected, health.chargingStatus != nil else {
            optimisticTargetPercent = nil
            restoreTargetSelection(fallback: state.confirmedTargetPercent ?? percent)
            appendLog("target write skipped: charger not connected")
            return
        }
        guard !hasBlockingOperation else {
            queuedTargetPercent = percent
            appendLog("target write queued: \(percent)%")
            return
        }
        if state.confirmedTargetPercent == percent {
            optimisticTargetPercent = nil
            restoreTargetSelection(fallback: percent)
            appendLog("target write skipped: \(percent)% already confirmed")
            return
        }
        isWriting = true
        state.status = "Writing \(percent)%"
        appendLog("target write sent: \(percent)%")
        requestRender()
        do {
            let snapshot = try await useCases.setChargeTarget.execute(percent: percent)
            snapshot.logLines.forEach { appendLog($0) }
            pendingTargetConfirmationPercent = percent
            state.status = "Confirming \(percent)%"
            scheduleTargetConfirmationTimeout(percent: percent)
        } catch {
            optimisticTargetPercent = nil
            restoreTargetSelection(fallback: state.confirmedTargetPercent ?? percent)
            state.status = "Write failed"
            state.error = String(describing: error)
            appendLog("target write failed: \(error)")
        }
        finishWrite()
    }

    private func updateTelemetryState(from health: BikeBatteryHealth) {
        guard let charging = health.chargingStatus else {
            state.isEnabled = false
            state.status = "Waiting for charger telemetry"
            return
        }
        let confirmed = stateUpdater.synchronize(
            charging: charging,
            state: &state,
            interaction: .init(
                isDraggingPower: isDraggingPower,
                optimisticPowerWatts: optimisticPowerWatts,
                pendingPowerConfirmationWatts: pendingPowerConfirmationWatts,
                isDraggingTarget: isDraggingTarget,
                optimisticTargetPercent: optimisticTargetPercent,
                pendingTargetConfirmationPercent: pendingTargetConfirmationPercent
            )
        )
        if logger.appendTelemetry(charging: charging) {
            requestRender()
        }
        confirmPendingValuesIfNeeded(
            confirmedWatts: confirmed.watts,
            confirmedTargetPercent: confirmed.targetPercent
        )
    }

    private func confirmPendingValuesIfNeeded(confirmedWatts: Int, confirmedTargetPercent: Int) {
        if let pending = pendingPowerConfirmationWatts, confirmedWatts == pending {
            pendingPowerConfirmationWatts = nil
            optimisticPowerWatts = nil
            taskScheduler.cancelPowerConfirmation()
            state.status = "Confirmed \(pending) W"
            state.error = nil
            appendLog("write confirmed by 5001.maximumPower: \(pending) W")
            drainQueuedWriteIfNeeded()
        }
        if let pending = pendingTargetConfirmationPercent, confirmedTargetPercent == pending {
            pendingTargetConfirmationPercent = nil
            optimisticTargetPercent = nil
            taskScheduler.cancelTargetConfirmation()
            state.status = "Confirmed \(pending)%"
            state.error = nil
            appendLog("target write confirmed by 5001.maximumStateOfCharge: \(pending)%")
            drainQueuedWriteIfNeeded()
        }
    }

    private var hasBlockingOperation: Bool {
        isWriting
            || pendingPowerConfirmationWatts != nil
            || pendingTargetConfirmationPercent != nil
    }

    private var isChargerConnected: Bool {
        health.chargeState == .connected || health.chargeState == .charging
    }

    private func normalizedPowerWatts(_ watts: Int) -> Int {
        stateUpdater.normalizedPowerWatts(watts, state: state)
    }
    private func normalizedTargetPercent(_ percent: Int) -> Int {
        stateUpdater.normalizedTargetPercent(percent)
    }

    private func schedulePowerConfirmationTimeout(watts: Int) {
        taskScheduler.schedulePowerConfirmation { [weak self] in
            guard let self,
                  self.pendingPowerConfirmationWatts == watts
            else {
                return
            }
            let actual = self.state.confirmedWatts
            self.pendingPowerConfirmationWatts = nil
            self.optimisticPowerWatts = nil
            if let actual {
                self.restorePowerSelection(fallback: actual)
            }
            let actualText = actual.map(String.init) ?? "unknown"
            self.state.status = "Confirmation mismatch"
            self.state.error = "5001.maximumPower=\(actualText) W, target=\(watts) W"
            self.appendLog("mismatch: 5001.maximumPower=\(actualText) W target=\(watts) W")
            self.requestRender()
            self.drainQueuedWriteIfNeeded()
        }
    }

    private func scheduleTargetConfirmationTimeout(percent: Int) {
        taskScheduler.scheduleTargetConfirmation { [weak self] in
            guard let self,
                  self.pendingTargetConfirmationPercent == percent
            else {
                return
            }
            let actual = self.state.confirmedTargetPercent
            self.pendingTargetConfirmationPercent = nil
            self.optimisticTargetPercent = nil
            if let actual {
                self.restoreTargetSelection(fallback: actual)
            }
            let actualText = actual.map(String.init) ?? "unknown"
            self.state.status = "Confirmation mismatch"
            self.state.error = "5001.maximumStateOfCharge=\(actualText)%, target=\(percent)%"
            self.appendLog(
                "target mismatch: 5001.maximumStateOfCharge=\(actualText)% target=\(percent)%"
            )
            self.requestRender()
            self.drainQueuedWriteIfNeeded()
        }
    }
    private func finishWrite() {
        isWriting = false
        requestRender()
        drainQueuedWriteIfNeeded()
    }

    private func appendLog(_ line: String) {
        logger.append(line)
        requestRender()
    }

    private func restorePowerSelection(fallback watts: Int) {
        stateUpdater.restorePowerSelection(fallbackWatts: watts, state: &state)
    }

    private func restoreTargetSelection(fallback percent: Int) {
        stateUpdater.restoreTargetSelection(fallbackPercent: percent, state: &state)
    }

    private func drainQueuedWriteIfNeeded() {
        guard !hasBlockingOperation else { return }
        if let watts = queuedPowerWatts {
            queuedPowerWatts = nil
            Task { @MainActor [weak self] in
                await self?.writePowerLimit(watts)
            }
            return
        }
        if let percent = queuedTargetPercent {
            queuedTargetPercent = nil
            Task { @MainActor [weak self] in
                await self?.writeTarget(percent)
            }
        }
    }
}
