import BikeDomain
import Foundation
import SettingsDomain

struct BikeLiveActivityUseCases {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
}

@MainActor
final class BikeLiveActivityController {
    private let useCases: BikeLiveActivityUseCases
    private let activityClient: BikeLiveActivityClient
    private let clock: any BikeLiveActivityClock
    private let updateInterval: TimeInterval
    private let stateMapper: BikeLiveActivityStateMapper

    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var connection = BikeConnection()
    private var settings = AppSettings()
    private var tasks: [Task<Void, Never>] = []
    private var evaluationTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    private var canShowLiveActivity = false
    private var isSetupCompleted = false
    private var isStartingBatteryHealthMonitoring = false
    private var isMonitoringBatteryHealth = false
    private var lastContentState: BikeLiveActivityContentState?
    private var lastUpdateDate: Date?

    init(
        useCases: BikeLiveActivityUseCases,
        activityClient: BikeLiveActivityClient,
        clock: any BikeLiveActivityClock,
        updateInterval: TimeInterval,
        stateMapper: BikeLiveActivityStateMapper
    ) {
        self.useCases = useCases
        self.activityClient = activityClient
        self.clock = clock
        self.updateInterval = updateInterval
        self.stateMapper = stateMapper
    }

    deinit {
        tasks.forEach { $0.cancel() }
        evaluationTask?.cancel()
        stopTask?.cancel()
    }

    func start() {
        guard tasks.isEmpty else { return }
        stopTask?.cancel()
        stopTask = nil
        let observeTelemetry = useCases.observeTelemetry
        tasks.append(Task { [weak self] in
            let stream = await observeTelemetry.execute()
            for await telemetry in stream {
                guard !Task.isCancelled, let self else { return }
                self.telemetry = telemetry
                await self.evaluate()
            }
        })
        let observeBatteryHealth = useCases.observeBatteryHealth
        tasks.append(Task { [weak self] in
            let stream = await observeBatteryHealth.execute()
            for await batteryHealth in stream {
                guard !Task.isCancelled, let self else { return }
                self.batteryHealth = batteryHealth
                await self.evaluate()
            }
        })
        let observeConnection = useCases.observeConnection
        tasks.append(Task { [weak self] in
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled, let self else { return }
                self.connection = connection
                await self.evaluate()
            }
        })
        let observeSettings = useCases.observeSettings
        tasks.append(Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled, let self else { return }
                self.settings = settings
                await self.evaluate()
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        evaluationTask?.cancel()
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            await self?.stopMonitoringIfNeeded()
        }
    }

    func setCanShowLiveActivity(_ canShow: Bool) {
        canShowLiveActivity = canShow
        scheduleEvaluation()
    }

    func setIsSetupCompleted(_ isCompleted: Bool) {
        isSetupCompleted = isCompleted
        scheduleEvaluation()
    }

    private func scheduleEvaluation() {
        evaluationTask?.cancel()
        evaluationTask = Task { [weak self] in
            await self?.evaluate()
        }
    }

    private func evaluate() async {
        guard canShowLiveActivity || activityClient.isActive else { return }
        let snapshot = stateMapper.map(
            telemetry: telemetry,
            batteryHealth: batteryHealth,
            connection: connection,
            settings: settings,
            now: clock.now
        )
        let state = snapshot.contentState

        if !activityClient.isActive {
            guard canShowLiveActivity else { return }
            guard canStartActivity(with: snapshot) else { return }
            do {
                try await activityClient.start(vin: activityVIN, state: state)
                lastContentState = state
                lastUpdateDate = clock.now
                await updateBatteryHealthMonitoring(for: state)
            } catch {
                await stopMonitoringIfNeeded()
            }
            return
        }

        if shouldEndActivity(with: snapshot) {
            await activityClient.end(state: state)
            await stopMonitoringIfNeeded()
            lastContentState = nil
            lastUpdateDate = nil
            return
        }

        await updateBatteryHealthMonitoring(for: state)
        guard shouldUpdate(with: state) else { return }
        await activityClient.update(state: state)
        lastContentState = state
        lastUpdateDate = clock.now
    }

    private func canStartActivity(with snapshot: BikeLiveActivitySnapshot) -> Bool {
        isSetupCompleted
            && snapshot.hasRecentTelemetry
            && snapshot.hasDisplayableTelemetry
            && snapshot.isReceivingTelemetry
            && snapshot.isLiveRunState
            && snapshot.contentState.phase != .complete
            && snapshot.contentState.mode != .stale
            && snapshot.contentState.mode != .connectionLost
    }

    private func updateBatteryHealthMonitoring(for state: BikeLiveActivityContentState) async {
        if state.mode == .charging {
            await startMonitoringIfNeeded()
        } else {
            await stopMonitoringIfNeeded()
        }
    }

    private func startMonitoringIfNeeded() async {
        guard !isMonitoringBatteryHealth, !isStartingBatteryHealthMonitoring else { return }
        isStartingBatteryHealthMonitoring = true
        do {
            try await useCases.startBatteryHealthMonitoring.execute()
            isStartingBatteryHealthMonitoring = false
            guard activityClient.isActive, telemetry.runState == .charging else {
                await useCases.stopBatteryHealthMonitoring.execute()
                return
            }
            isMonitoringBatteryHealth = true
        } catch {
            isStartingBatteryHealthMonitoring = false
            isMonitoringBatteryHealth = false
        }
    }

    private func stopMonitoringIfNeeded() async {
        guard isMonitoringBatteryHealth else { return }
        isMonitoringBatteryHealth = false
        await useCases.stopBatteryHealthMonitoring.execute()
    }

    private func shouldUpdate(with state: BikeLiveActivityContentState) -> Bool {
        guard let lastContentState, let lastUpdateDate else { return true }
        guard state != lastContentState else { return false }
        if state.phase != lastContentState.phase {
            return true
        }
        if state.mode != lastContentState.mode
            || state.runState != lastContentState.runState
            || state.modeIndex != lastContentState.modeIndex
            || state.isFaultActive != lastContentState.isFaultActive
            || state.isConnectionLost != lastContentState.isConnectionLost {
            return true
        }
        return clock.now.timeIntervalSince(lastUpdateDate) >= updateInterval
    }

    private func shouldEndActivity(with snapshot: BikeLiveActivitySnapshot) -> Bool {
        let state = snapshot.contentState
        if !isSetupCompleted { return true }
        if state.phase == .complete { return true }
        if !snapshot.hasRecentTelemetry, state.mode != .connectionLost, state.mode != .stale { return true }
        if !snapshot.isLiveRunState, !state.isFaultActive, state.mode != .connectionLost {
            return true
        }
        return false
    }

    private var activityVIN: String {
        let vin = telemetry.vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return vin.isEmpty ? "Stark Varg" : vin
    }
}
