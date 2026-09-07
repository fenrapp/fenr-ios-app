import BikeDomain
import Foundation
import Observation

@MainActor
@Observable
public final class ChargeControlSession {
    public private(set) var state: ChargeControlState {
        didSet { stateEmitter.send(state) }
    }

    public var logLines: [String] { logger.lines }

    private let useCases: ChargeControlUseCases
    private var logger: ChargeControlLogStore
    private let stateUpdater: ChargeControlStateUpdater
    private let taskScheduler: ChargeControlTaskScheduler
    private let stateEmitter: ChargeControlStateEmitter
    @ObservationIgnored private var health = BikeBatteryHealth()
    @ObservationIgnored private var operations = ChargeControlOperationState()
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var queuedWriteTask: Task<Void, Never>?
    @ObservationIgnored private var queuedWriteTaskID: UUID?

    public init(
        useCases: ChargeControlUseCases,
        logger: ChargeControlLogStore,
        stateUpdater: ChargeControlStateUpdater,
        taskScheduler: ChargeControlTaskScheduler,
        stateEmitter: ChargeControlStateEmitter,
        initialState: ChargeControlState = .init()
    ) {
        self.useCases = useCases
        self.logger = logger
        self.stateUpdater = stateUpdater
        self.taskScheduler = taskScheduler
        self.stateEmitter = stateEmitter
        state = initialState
    }

    deinit {
        preparationTask?.cancel()
        queuedWriteTask?.cancel()
    }

    public func setPowerLimit(watts: Double) {
        guard state.canAcceptInput else { return }
        let finalWatts = stateUpdater.normalizedPowerWatts(Int(watts.rounded()), state: state)
        guard state.selectedWatts != Double(finalWatts) else { return }
        operations.select(.power(watts: finalWatts))
        state.selectedWatts = Double(finalWatts)
        state.phase = .updating
        taskScheduler.schedulePowerDebounce { [weak self] in
            await self?.write(.power(watts: finalWatts))
        }
    }

    public func setTarget(percent: Double) {
        guard state.canAcceptInput else { return }
        let finalPercent = stateUpdater.normalizedTargetPercent(Int(percent.rounded()))
        guard state.selectedTargetPercent != Double(finalPercent) else { return }
        operations.select(.target(percent: finalPercent))
        state.selectedTargetPercent = Double(finalPercent)
        state.phase = .updating
        taskScheduler.scheduleTargetDebounce { [weak self] in
            await self?.write(.target(percent: finalPercent))
        }
    }

    public func receive(_ health: BikeBatteryHealth) {
        self.health = health
        guard isConnected, let charging = health.chargingStatus else {
            resetAfterDisconnect()
            return
        }
        synchronize(charging)
        prepareIfNeeded(chargingStatus: charging)
    }

    private func prepareIfNeeded(chargingStatus: BikeChargingStatus) {
        guard let generation = operations.beginPreparation() else { return }
        state.isVisible = true
        state.phase = .preparing
        state.status = .preparing
        let prepare = useCases.prepare
        preparationTask = Task { @MainActor [weak self] in
            defer { self?.finishPreparation(generation: generation) }
            do {
                let snapshot = try await prepare.execute(chargingStatus: chargingStatus)
                guard !Task.isCancelled,
                      let self,
                      operations.belongsToCurrentConnection(generation),
                      isConnected else { return }
                stateUpdater.applyPreparation(snapshot, to: &state)
                snapshot.logLines.forEach { logger.append($0) }
            } catch is CancellationError {
                return
            } catch {
                guard let self, operations.belongsToCurrentConnection(generation) else { return }
                stateUpdater.applyPreparationFailure(to: &state)
                logger.append("prepare failed: \(error)")
            }
        }
    }

    private func finishPreparation(generation: Int) {
        guard operations.belongsToCurrentConnection(generation) else { return }
        operations.finishPreparation()
        preparationTask = nil
    }

    private func write(_ command: ChargeControlCommand) async {
        guard canWrite else {
            rollback(command)
            return
        }
        guard !operations.hasBlockingOperation else {
            operations.enqueue(command)
            return
        }
        guard !command.isConfirmed(in: state) else {
            operations.clearOptimisticValue(matching: command)
            restoreSelectionUnlessSuperseded(for: command)
            markReadyUnlessUpdating()
            return
        }

        let generation = operations.beginWrite()
        state.phase = .updating
        state.status = .writing(command.settingValue)
        do {
            let snapshot = try await execute(command)
            guard operations.belongsToCurrentConnection(generation), canWrite else { return }
            snapshot.logLines.forEach { logger.append($0) }
            operations.awaitConfirmation(of: command)
            if command.isConfirmed(in: state) {
                completeConfirmation(command)
            } else {
                state.status = .confirming(command.settingValue)
                scheduleConfirmationTimeout(for: command)
            }
        } catch {
            guard operations.belongsToCurrentConnection(generation) else { return }
            rollback(command)
            markFailed(.writeFailed)
            logger.append("write failed: \(error)")
        }
        operations.finishWrite()
        drainQueuedWriteIfNeeded()
    }

    private func execute(_ command: ChargeControlCommand) async throws -> BikeChargePowerControlSnapshot {
        switch command {
        case .power(let watts):
            try await useCases.setPowerLimit.execute(watts: watts)
        case .target(let percent):
            try await useCases.setTarget.execute(percent: percent)
        }
    }

    private func synchronize(_ charging: BikeChargingStatus) {
        let confirmed = stateUpdater.synchronize(
            charging: charging,
            state: &state,
            interaction: operations.interaction
        )
        logger.appendTelemetry(charging: charging)
        confirmIfNeeded(confirmed)
    }

    private func confirmIfNeeded(_ confirmed: ChargeControlConfirmedValues) {
        guard let command = operations.pendingConfirmation,
              command.matches(
                  confirmedWatts: confirmed.watts,
                  confirmedTargetPercent: confirmed.targetPercent
              ) else { return }
        completeConfirmation(command)
    }

    private func completeConfirmation(_ command: ChargeControlCommand) {
        guard operations.clearPendingConfirmation(command) else { return }
        cancelConfirmation(for: command)
        markReadyUnlessUpdating(status: .confirmed(command.settingValue))
        logger.append("5001 confirmed: \(command.statusValue)")
        drainQueuedWriteIfNeeded()
    }

    private func scheduleConfirmationTimeout(for command: ChargeControlCommand) {
        let operation: @MainActor @Sendable () async -> Void = { [weak self] in
            self?.confirmationTimedOut(command)
        }
        switch command {
        case .power: taskScheduler.schedulePowerConfirmation(operation: operation)
        case .target: taskScheduler.scheduleTargetConfirmation(operation: operation)
        }
    }

    private func confirmationTimedOut(_ command: ChargeControlCommand) {
        guard operations.clearPendingConfirmation(command) else { return }
        restoreSelectionUnlessSuperseded(for: command)
        let error = command.mismatchDescription(in: state)
        markFailed(.confirmationTimedOut)
        logger.append("mismatch: \(error)")
        drainQueuedWriteIfNeeded()
    }

    private var isConnected: Bool {
        health.chargeState == .connected || health.chargeState == .charging
    }

    private var canWrite: Bool { state.isEnabled && isConnected && health.chargingStatus != nil }

    private func rollback(_ command: ChargeControlCommand) {
        operations.clearOptimisticValue(matching: command)
        restoreSelectionUnlessSuperseded(for: command)
    }

    private func restoreSelectionUnlessSuperseded(for command: ChargeControlCommand) {
        guard !operations.hasOptimisticValue(controlling: command) else { return }
        restoreSelection(for: command)
    }

    private func restoreSelection(for command: ChargeControlCommand) {
        switch command {
        case .power(let watts):
            stateUpdater.restorePowerSelection(fallbackWatts: state.confirmedWatts ?? watts, state: &state)
        case .target(let percent):
            stateUpdater.restoreTargetSelection(
                fallbackPercent: state.confirmedTargetPercent ?? percent,
                state: &state
            )
        }
    }

    private func cancelConfirmation(for command: ChargeControlCommand) {
        switch command {
        case .power: taskScheduler.cancelPowerConfirmation()
        case .target: taskScheduler.cancelTargetConfirmation()
        }
    }

    private func resetAfterDisconnect() {
        guard state.isVisible || operations.hasAttemptedPreparation || operations.hasBlockingOperation else { return }
        preparationTask?.cancel()
        preparationTask = nil
        queuedWriteTask?.cancel()
        queuedWriteTask = nil
        queuedWriteTaskID = nil
        taskScheduler.cancelAll()
        operations.reset()
        state = ChargeControlState()
    }

    private func markReady(status: ChargeControlStatus = .ready) {
        state.phase = .ready
        state.status = status
        state.failure = nil
    }

    private func markReadyUnlessUpdating(status: ChargeControlStatus = .ready) {
        if operations.hasOptimisticSelection {
            state.phase = .updating
            state.status = .updating
            state.failure = nil
        } else {
            markReady(status: status)
        }
    }

    private func markFailed(_ failure: ChargeControlFailure) {
        state.phase = .failed
        state.status = .updateFailed
        state.failure = failure
    }
}

extension ChargeControlSession {
    private func drainQueuedWriteIfNeeded() {
        guard let command = operations.nextQueuedCommand() else { return }
        let generation = operations.connectionGeneration
        let taskID = UUID()
        queuedWriteTask?.cancel()
        queuedWriteTaskID = taskID
        queuedWriteTask = Task { @MainActor [weak self] in
            guard let self, operations.belongsToCurrentConnection(generation) else { return }
            await write(command)
            guard queuedWriteTaskID == taskID else { return }
            queuedWriteTask = nil
            queuedWriteTaskID = nil
        }
    }

    public func observeState() -> AsyncStream<ChargeControlState> {
        stateEmitter.stream(replaying: state)
    }

    public func stopAndWait() async {
        let pendingPreparation = preparationTask
        let pendingWrite = queuedWriteTask
        pendingPreparation?.cancel()
        pendingWrite?.cancel()
        await taskScheduler.cancelAndWait()
        await pendingPreparation?.value
        await pendingWrite?.value
        resetAfterDisconnect()
    }

}
