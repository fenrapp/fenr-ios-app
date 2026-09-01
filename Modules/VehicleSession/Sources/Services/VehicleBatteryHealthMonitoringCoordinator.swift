import BikeDomain
import Foundation

public actor VehicleBatteryHealthMonitoringCoordinator {
    public struct Snapshot: Equatable, Sendable {
        public let health: BikeBatteryHealth
        public let state: VehicleBatteryHealthMonitoringState
        public let revision: Int

        public init(
            health: BikeBatteryHealth = .init(),
            state: VehicleBatteryHealthMonitoringState = .inactive,
            revision: Int = 0
        ) {
            self.health = health
            self.state = state
            self.revision = revision
        }
    }

    private let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    private let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    private let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    private var consumers: Set<UUID> = []
    private var currentSnapshot = Snapshot()
    private var outputContinuations: [UUID: AsyncStream<Snapshot>.Continuation] = [:]
    private var startTask: Task<Void, Never>?
    private var startGeneration: Int?
    private var monitoringGeneration = 0
    private var stopTask: Task<Void, Never>?
    private var observationTask: Task<Void, Never>?
    private var isSessionReady = false
    private var isMonitoringActive = false
    private var isStopping = false
    private var hasPendingStart = false
    private var hasPendingStop = false

    public init(
        observeBatteryHealth: ObserveBikeBatteryHealthUseCase,
        startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase,
        stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    ) {
        self.observeBatteryHealth = observeBatteryHealth
        self.startBatteryHealthMonitoring = startBatteryHealthMonitoring
        self.stopBatteryHealthMonitoring = stopBatteryHealthMonitoring
    }

    deinit {
        startTask?.cancel()
        stopTask?.cancel()
        observationTask?.cancel()
        outputContinuations.values.forEach { $0.finish() }
    }

    func observe() -> AsyncStream<Snapshot> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            outputContinuations[id] = continuation
            continuation.yield(currentSnapshot)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeOutputContinuation(id) }
            }
        }
    }

    func snapshot() -> Snapshot {
        currentSnapshot
    }

    func prepareLeaseChange(
        required: Bool,
        consumerID: UUID,
        isSessionReady: Bool
    ) -> Snapshot {
        self.isSessionReady = isSessionReady
        if required {
            consumers.insert(consumerID)
        } else {
            consumers.remove(consumerID)
        }
        reconcileDesiredState(
            allowsFailedRetry: required,
            stopsActiveMonitoring: !required && consumers.isEmpty
        )
        return currentSnapshot
    }

    func prepareReadinessChange(isSessionReady: Bool) -> Snapshot {
        let didBecomeReady = !self.isSessionReady && isSessionReady
        self.isSessionReady = isSessionReady
        reconcileDesiredState(
            allowsFailedRetry: didBecomeReady,
            stopsActiveMonitoring: false
        )
        return currentSnapshot
    }

    func resumePendingWork() {
        guard !isStopping else { return }
        if hasPendingStop, stopTask == nil {
            startPendingStop()
            return
        }
        guard stopTask == nil, startTask == nil else { return }
        if hasPendingStart, wantsMonitoring {
            startPendingMonitoring()
        }
    }

    func stop() async -> Snapshot {
        isStopping = true
        isSessionReady = false
        consumers.removeAll()
        hasPendingStart = false
        hasPendingStop = false
        monitoringGeneration &+= 1
        startTask?.cancel()
        observationTask?.cancel()
        if let observationTask {
            await observationTask.value
        }
        observationTask = nil
        if let startTask {
            await startTask.value
        }
        if let stopTask {
            await stopTask.value
        } else if isMonitoringActive {
            await stopBatteryHealthMonitoring.execute()
            isMonitoringActive = false
        }
        updateSnapshot(health: .init(), state: .inactive)
        isStopping = false
        return currentSnapshot
    }
}

private extension VehicleBatteryHealthMonitoringCoordinator {
    var wantsMonitoring: Bool {
        isSessionReady && !consumers.isEmpty && !isStopping
    }

    func reconcileDesiredState(
        allowsFailedRetry: Bool,
        stopsActiveMonitoring: Bool
    ) {
        guard wantsMonitoring else {
            hasPendingStart = false
            monitoringGeneration &+= 1
            startTask?.cancel()
            observationTask?.cancel()
            observationTask = nil
            if isMonitoringActive {
                if stopsActiveMonitoring {
                    hasPendingStop = true
                } else {
                    isMonitoringActive = false
                }
            }
            updateSnapshot(health: .init(), state: .inactive)
            return
        }

        if isMonitoringActive, stopTask == nil, !hasPendingStop {
            hasPendingStart = false
            updateSnapshot(health: currentSnapshot.health, state: .active)
            return
        }
        if case .failed = currentSnapshot.state, !allowsFailedRetry {
            return
        }
        hasPendingStart = true
        updateSnapshot(health: .init(), state: .starting)
    }

    func startPendingMonitoring() {
        guard startTask == nil,
              stopTask == nil,
              !isMonitoringActive,
              wantsMonitoring else {
            return
        }
        hasPendingStart = false
        monitoringGeneration &+= 1
        let generation = monitoringGeneration
        startGeneration = generation
        let start = startBatteryHealthMonitoring
        startTask = Task { [weak self] in
            let result: Result<Void, Error>
            do {
                try await start.execute()
                result = .success(())
            } catch {
                result = .failure(error)
            }
            await self?.finishStart(
                result,
                generation: generation,
                wasCancelled: Task.isCancelled
            )
        }
    }

    func finishStart(
        _ result: Result<Void, Error>,
        generation: Int,
        wasCancelled: Bool
    ) async {
        guard startGeneration == generation else {
            if case .success = result {
                await stopBatteryHealthMonitoring.execute()
            }
            return
        }
        let canActivate = generation == monitoringGeneration
            && !wasCancelled
            && wantsMonitoring

        if case .success = result, canActivate {
            startTask = nil
            startGeneration = nil
            hasPendingStart = false
            isMonitoringActive = true
            updateSnapshot(health: .init(), state: .active)
            startObservation(generation: generation)
            return
        }

        if case .success = result {
            await stopBatteryHealthMonitoring.execute()
        }
        startTask = nil
        startGeneration = nil
        if generation == monitoringGeneration,
           case .failure(let error) = result,
           wantsMonitoring {
            updateSnapshot(health: .init(), state: .failed(String(describing: error)))
        } else if !wantsMonitoring || wasCancelled || generation != monitoringGeneration {
            updateSnapshot(health: .init(), state: .inactive)
        }
        if wantsMonitoring, generation != monitoringGeneration {
            hasPendingStart = true
            updateSnapshot(health: .init(), state: .starting)
        }
        resumePendingWork()
    }

    func startPendingStop() {
        guard stopTask == nil else { return }
        hasPendingStop = false
        observationTask?.cancel()
        observationTask = nil
        let stop = stopBatteryHealthMonitoring
        stopTask = Task { [weak self] in
            await stop.execute()
            await self?.finishStop()
        }
    }

    func finishStop() {
        stopTask = nil
        isMonitoringActive = false
        if wantsMonitoring {
            hasPendingStart = true
            updateSnapshot(health: .init(), state: .starting)
        } else {
            updateSnapshot(health: .init(), state: .inactive)
        }
        resumePendingWork()
    }

    func startObservation(generation: Int) {
        guard observationTask == nil else { return }
        let observe = observeBatteryHealth
        observationTask = Task { [weak self] in
            let stream = await observe.execute()
            for await value in stream where !Task.isCancelled {
                await self?.receive(value, generation: generation)
            }
        }
    }

    func receive(_ value: BikeBatteryHealth, generation: Int) {
        guard generation == monitoringGeneration,
              isMonitoringActive,
              wantsMonitoring else {
            return
        }
        updateSnapshot(health: value, state: .active)
    }

    func updateSnapshot(
        health: BikeBatteryHealth,
        state: VehicleBatteryHealthMonitoringState
    ) {
        guard health != currentSnapshot.health || state != currentSnapshot.state else { return }
        currentSnapshot = Snapshot(
            health: health,
            state: state,
            revision: currentSnapshot.revision + 1
        )
        outputContinuations.values.forEach { $0.yield(currentSnapshot) }
    }

    func removeOutputContinuation(_ id: UUID) {
        outputContinuations[id] = nil
    }
}
