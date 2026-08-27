import Foundation
import VehicleSession

@MainActor
final class BikeLiveActivityController {
    private let vehicleSession: any VehicleSessionService
    private let activityClient: BikeLiveActivityClient
    private let clock: any BikeLiveActivityClock
    private let updateInterval: TimeInterval
    private let stateMapper: BikeLiveActivityStateMapper

    private var snapshot = VehicleSessionSnapshot()
    private var observationTask: Task<Void, Never>?
    private var evaluationTask: Task<Void, Never>?
    private var needsEvaluation = false
    private var isStarted = false
    private var canShowLiveActivity = false
    private var isSetupCompleted = false
    private let batteryHealthConsumerID = UUID()
    private var isRequestingBatteryHealth = false
    private var lastContentState: BikeLiveActivityContentState?
    private var lastUpdateDate: Date?

    init(
        vehicleSession: any VehicleSessionService,
        activityClient: BikeLiveActivityClient,
        clock: any BikeLiveActivityClock,
        updateInterval: TimeInterval,
        stateMapper: BikeLiveActivityStateMapper
    ) {
        self.vehicleSession = vehicleSession
        self.activityClient = activityClient
        self.clock = clock
        self.updateInterval = updateInterval
        self.stateMapper = stateMapper
    }

    deinit {
        observationTask?.cancel()
        evaluationTask?.cancel()
    }

    func start() {
        guard observationTask == nil else { return }
        isStarted = true
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled, let self else { return }
                self.snapshot = snapshot
                self.scheduleEvaluation()
            }
        }
    }

    func stop() async {
        isStarted = false
        observationTask?.cancel()
        observationTask = nil
        evaluationTask?.cancel()
        await evaluationTask?.value
        evaluationTask = nil
        needsEvaluation = false
        await setBatteryHealthRequired(false)
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
        needsEvaluation = true
        guard evaluationTask == nil, isStarted else { return }
        evaluationTask = Task { [weak self] in
            await self?.runEvaluationLoop()
        }
    }

    private func runEvaluationLoop() async {
        while isStarted, needsEvaluation, !Task.isCancelled {
            needsEvaluation = false
            await evaluate()
        }
        evaluationTask = nil
        if isStarted, needsEvaluation {
            scheduleEvaluation()
        }
    }

    private func evaluate() async {
        guard isStarted, !Task.isCancelled else { return }
        guard canShowLiveActivity || activityClient.isActive else { return }
        let snapshot = stateMapper.map(
            snapshot: snapshot,
            now: clock.now
        )
        let state = snapshot.contentState

        if !activityClient.isActive {
            guard canShowLiveActivity else { return }
            guard canStartActivity(with: snapshot) else { return }
            do {
                try await activityClient.start(vin: activityVIN, state: state)
                guard isStarted, !Task.isCancelled else { return }
                lastContentState = state
                lastUpdateDate = clock.now
                await updateBatteryHealthMonitoring(for: state)
            } catch {
                await setBatteryHealthRequired(false)
            }
            return
        }

        if shouldEndActivity(with: snapshot) {
            await activityClient.end(state: state)
            guard isStarted, !Task.isCancelled else { return }
            await setBatteryHealthRequired(false)
            lastContentState = nil
            lastUpdateDate = nil
            return
        }

        await updateBatteryHealthMonitoring(for: state)
        guard isStarted, !Task.isCancelled else { return }
        guard shouldUpdate(with: state) else { return }
        await activityClient.update(state: state)
        guard isStarted, !Task.isCancelled else { return }
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
            await setBatteryHealthRequired(true)
        } else {
            await setBatteryHealthRequired(false)
        }
    }

    private func setBatteryHealthRequired(_ required: Bool) async {
        guard required != isRequestingBatteryHealth else { return }
        isRequestingBatteryHealth = required
        await vehicleSession.setBatteryHealthMonitoringRequired(
            required,
            consumerID: batteryHealthConsumerID
        )
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
        let preferredVIN = snapshot.profile?.vin ?? snapshot.telemetry.vin
        let vin = preferredVIN.trimmingCharacters(in: .whitespacesAndNewlines)
        return vin.isEmpty ? "Stark Varg" : vin
    }
}
