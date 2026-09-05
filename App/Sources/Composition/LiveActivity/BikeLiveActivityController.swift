import Foundation
import RideDashboard
import VehicleSession

@MainActor
final class BikeLiveActivityController {
    private let vehicleSession: any VehicleSessionService
    private let activityClient: BikeLiveActivityClient
    private let clock: any BikeLiveActivityClock
    private let timing: BikeLiveActivityTiming
    private let continuityPolicy: RideDashboardContinuityPolicy
    private let updatePolicy: BikeLiveActivityUpdatePolicy
    private let reconnectionNoticeDelay: Duration
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
    private var lastStableContentState: BikeLiveActivityContentState?
    private var lastUpdateDate: Date?
    private var reconnectionNoticeTask: Task<Void, Never>?
    private var reconnectionNoticeGeneration = 0
    private var isShowingReconnectionNotice = false
    private var requiresImmediateRecoveryUpdate = false

    init(
        vehicleSession: any VehicleSessionService,
        activityClient: BikeLiveActivityClient,
        clock: any BikeLiveActivityClock,
        timing: BikeLiveActivityTiming,
        continuityPolicy: RideDashboardContinuityPolicy,
        updatePolicy: BikeLiveActivityUpdatePolicy,
        reconnectionNoticeDelay: Duration,
        stateMapper: BikeLiveActivityStateMapper
    ) {
        self.vehicleSession = vehicleSession
        self.activityClient = activityClient
        self.clock = clock
        self.timing = timing
        self.continuityPolicy = continuityPolicy
        self.updatePolicy = updatePolicy
        self.reconnectionNoticeDelay = reconnectionNoticeDelay
        self.stateMapper = stateMapper
    }

    deinit {
        observationTask?.cancel()
        evaluationTask?.cancel()
        reconnectionNoticeTask?.cancel()
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
        reconnectionNoticeGeneration &+= 1
        reconnectionNoticeTask?.cancel()
        await reconnectionNoticeTask?.value
        reconnectionNoticeTask = nil
        isShowingReconnectionNotice = false
        requiresImmediateRecoveryUpdate = false
        needsEvaluation = false
        await setBatteryHealthRequired(false)
    }

    func endForExperienceChange() async {
        await stop()
        guard activityClient.isActive else { return }
        let state = lastContentState ?? stateMapper.map(snapshot: snapshot, now: clock.now).contentState
        await activityClient.end(state: state)
    }

    func setCanShowLiveActivity(_ canShow: Bool) {
        canShowLiveActivity = canShow
        scheduleEvaluation()
    }

    func setIsSetupCompleted(_ isCompleted: Bool) {
        isSetupCompleted = isCompleted
        scheduleEvaluation()
    }
}

private extension BikeLiveActivityController {
    func scheduleEvaluation() {
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

        let continuityPhase = continuityPolicy.phase(
            connectionState: self.snapshot.connection.state,
            hasLiveTelemetry: snapshot.hasRecentTelemetry
                && snapshot.hasDisplayableTelemetry
                && snapshot.isReceivingTelemetry
                && self.snapshot.isCanonicalTelemetryAvailable,
            hasValidPresentation: activityClient.isActive && lastStableContentState != nil
        )
        if continuityPhase == .recovering, activityClient.isActive {
            requiresImmediateRecoveryUpdate = true
            await preserveActivityDuringRecovery()
            return
        }
        let shouldForceUpdate = requiresImmediateRecoveryUpdate
        cancelReconnectionNotice()

        if !activityClient.isActive {
            guard canShowLiveActivity else { return }
            guard canStartActivity(with: snapshot) else { return }
            do {
                try await activityClient.start(vin: activityVIN, state: state)
                guard isStarted, !Task.isCancelled else { return }
                lastContentState = state
                lastStableContentState = state
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
            lastStableContentState = nil
            lastUpdateDate = nil
            return
        }

        await updateBatteryHealthMonitoring(for: state)
        guard isStarted, !Task.isCancelled else { return }
        guard shouldForceUpdate || shouldUpdate(with: state) else { return }
        await activityClient.update(state: state)
        guard isStarted, !Task.isCancelled else { return }
        requiresImmediateRecoveryUpdate = false
        lastContentState = state
        if continuityPhase == .live {
            lastStableContentState = state
        }
        lastUpdateDate = clock.now
    }

    private func canStartActivity(with mapped: BikeLiveActivitySnapshot) -> Bool {
        updatePolicy.canStart(mapped: mapped, source: snapshot, isSetupCompleted: isSetupCompleted)
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
        updatePolicy.shouldUpdate(
            state: state,
            previous: lastContentState,
            previousUpdateDate: lastUpdateDate,
            now: clock.now
        )
    }

    private func shouldEndActivity(with snapshot: BikeLiveActivitySnapshot) -> Bool {
        updatePolicy.shouldEnd(mapped: snapshot, isSetupCompleted: isSetupCompleted)
    }

    private func preserveActivityDuringRecovery() async {
        guard let stableState = lastStableContentState else { return }
        await updateBatteryHealthMonitoring(for: stableState)
        if isShowingReconnectionNotice {
            var reconnectingState = stableState
            reconnectingState.phase = .reconnecting
            reconnectingState.isConnectionLost = false
            guard shouldUpdate(with: reconnectingState) else { return }
            await activityClient.update(state: reconnectingState)
            guard isStarted, isShowingReconnectionNotice else { return }
            lastContentState = reconnectingState
            lastUpdateDate = clock.now
            return
        }
        guard reconnectionNoticeTask == nil, !isShowingReconnectionNotice else { return }
        let timing = timing
        let delay = reconnectionNoticeDelay
        let generation = reconnectionNoticeGeneration
        reconnectionNoticeTask = Task { [weak self] in
            do {
                try await timing.sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.publishReconnectionNotice(generation: generation)
        }
    }

    private func publishReconnectionNotice(generation: Int) async {
        guard generation == reconnectionNoticeGeneration,
              isStarted,
              activityClient.isActive,
              lastStableContentState != nil else {
            return
        }
        let mapped = stateMapper.map(snapshot: snapshot, now: clock.now)
        guard continuityPolicy.phase(
            connectionState: snapshot.connection.state,
            hasLiveTelemetry: mapped.hasRecentTelemetry
                && mapped.hasDisplayableTelemetry
                && mapped.isReceivingTelemetry
                && snapshot.isCanonicalTelemetryAvailable,
            hasValidPresentation: true
        ) == .recovering else {
            return
        }
        reconnectionNoticeTask = nil
        isShowingReconnectionNotice = true
        scheduleEvaluation()
    }

    private func cancelReconnectionNotice() {
        reconnectionNoticeGeneration &+= 1
        reconnectionNoticeTask?.cancel()
        reconnectionNoticeTask = nil
        isShowingReconnectionNotice = false
    }

    private var activityVIN: String {
        let preferredVIN = snapshot.profile?.vin ?? snapshot.telemetry.vin
        let vin = preferredVIN.trimmingCharacters(in: .whitespacesAndNewlines)
        return vin.isEmpty ? String(localized: .appDefaultBikeName) : vin
    }
}
