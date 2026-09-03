import BikeDomain
import Combine
import Foundation
import VehicleSession

@MainActor
public final class RideDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = RideDashboardViewState()
    @Published private(set) var cardLayout = DashboardCardLayout()

    private let mapper: RideDashboardMapper
    private let cardLayoutMapper: DashboardCardLayoutMapper
    private let vehicleSession: any VehicleSessionService
    private let timing: RideDashboardTiming
    private let continuityPolicy: RideDashboardContinuityPolicy
    private let temperatureMonitoringConsumerID = UUID()
    private var snapshot = VehicleSessionSnapshot()
    private var observationTask: Task<Void, Never>?
    private var temperatureMonitoringTask: Task<Void, Never>?
    private var isRequestingTemperatureMonitoring = false
    private var statusSnapshotRefreshTask: Task<Void, Never>?
    private var didRefreshStatusForTelemetrySession = false
    private var connectionStabilityTask: Task<Void, Never>?
    private var reconnectionNoticeTask: Task<Void, Never>?
    private var reconnectionNoticeGeneration = 0
    private var isShowingReconnectionNotice = false
    private var pendingLiveViewState: RideDashboardViewState?
    private var lastLiveViewState: RideDashboardViewState?
    private var lastLivePowerModeIndex: Int?
    private var cachedVehicleIdentity: String?
    private let initialConnectionStabilityPeriod: Duration
    private let reconnectionNoticeDelay: Duration

    public init(
        mapper: RideDashboardMapper,
        cardLayoutMapper: DashboardCardLayoutMapper,
        vehicleSession: any VehicleSessionService,
        timing: RideDashboardTiming,
        continuityPolicy: RideDashboardContinuityPolicy,
        initialConnectionStabilityPeriod: Duration,
        reconnectionNoticeDelay: Duration
    ) {
        self.mapper = mapper
        self.cardLayoutMapper = cardLayoutMapper
        self.vehicleSession = vehicleSession
        self.timing = timing
        self.continuityPolicy = continuityPolicy
        self.initialConnectionStabilityPeriod = initialConnectionStabilityPeriod
        self.reconnectionNoticeDelay = reconnectionNoticeDelay
    }

    deinit {
        observationTask?.cancel()
        statusSnapshotRefreshTask?.cancel()
        connectionStabilityTask?.cancel()
        reconnectionNoticeTask?.cancel()
        guard isRequestingTemperatureMonitoring else { return }
        let previousRequest = temperatureMonitoringTask
        let vehicleSession = vehicleSession
        let consumerID = temperatureMonitoringConsumerID
        Task {
            await previousRequest?.value
            await vehicleSession.setBatteryHealthMonitoringRequired(false, consumerID: consumerID)
        }
    }

    func startObserving() {
        guard observationTask == nil else { return }
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.snapshot = snapshot
                self?.render()
            }
        }
    }

    func pausePresentation() {
        observationTask?.cancel()
        observationTask = nil
        statusSnapshotRefreshTask?.cancel()
        statusSnapshotRefreshTask = nil
        cancelPendingConnectionStability()
        cancelReconnectionNotice()
        setTemperatureMonitoringRequired(false)
    }

    func invalidateSession() {
        pausePresentation()
        snapshot = .init()
        didRefreshStatusForTelemetrySession = false
        cachedVehicleIdentity = nil
        clearCachedPresentation()
        publish(.init())
    }

    func stopObserving() {
        invalidateSession()
    }
}

#if DEBUG
extension RideDashboardViewModel {
    func setPreviewState(_ viewState: RideDashboardViewState) {
        self.viewState = viewState
    }
}
#endif

private extension RideDashboardViewModel {
    func render() {
        updateVehicleIdentity()
        let nextCardLayout = cardLayoutMapper.map(snapshot.settings.dashboardCardConfiguration)
        if nextCardLayout != cardLayout {
            cardLayout = nextCardLayout
        }
        let mappedViewState = mapper.map(
            telemetry: snapshot.telemetry,
            connection: snapshot.connection,
            speedKilometersPerHour: snapshot.resolvedSpeedKilometersPerHour,
            speedSource: snapshot.speedSource,
            progressBarMode: snapshot.settings.dashboardProgressBarMode,
            batteryIndicatorMode: snapshot.settings.dashboardBatteryIndicatorMode,
            temperatureDisplayMode: snapshot.settings.dashboardTemperatureDisplayMode,
            measurementSystem: snapshot.settings.measurementSystem,
            isGPSAvailable: snapshot.isGPSAvailable,
            powerModeNames: snapshot.settings.powerModeNames(forVIN: snapshot.profile?.vin)
        )
        updateViewState(with: mappedViewState)
        updateStatusSnapshotRefresh()
        if mappedViewState.hasTelemetry, snapshot.isCanonicalTelemetryAvailable {
            setTemperatureMonitoringRequired(snapshot.settings.dashboardTemperatureDisplayMode.isEnabled)
        } else if viewState.continuityPhase == .terminal {
            setTemperatureMonitoringRequired(false)
        }
    }

    private func updateViewState(with mappedViewState: RideDashboardViewState) {
        if mappedViewState.hasTelemetry, snapshot.isCanonicalTelemetryAvailable {
            let liveViewState = livePresentation(from: mappedViewState)
            if lastLiveViewState == nil {
                pendingLiveViewState = liveViewState
                publish(liveViewState.waitingForStableTelemetry())
                startConnectionStabilityPeriod()
                return
            }
            cancelPendingConnectionStability()
            cancelReconnectionNotice()
            lastLiveViewState = liveViewState
            lastLivePowerModeIndex = snapshot.telemetry.mode.displayIndex
            publish(liveViewState)
            return
        }

        cancelPendingConnectionStability()
        let phase = continuityPolicy.phase(
            connectionState: snapshot.connection.state,
            hasLiveTelemetry: false,
            hasValidPresentation: lastLiveViewState != nil
        )
        switch phase {
        case .recovering:
            guard let lastLiveViewState else { return }
            let notice = isShowingReconnectionNotice
                ? DashboardConnectionNoticeViewData()
                : nil
            publish(lastLiveViewState.withContinuity(.recovering, notice: notice))
            startReconnectionNoticeDelay()
        case .terminal:
            cancelReconnectionNotice()
            clearCachedPresentation()
            publish(mappedViewState.withContinuity(.terminal))
        case .cold:
            cancelReconnectionNotice()
            publish(mappedViewState.withContinuity(.cold))
        case .live:
            break
        }
    }

    private func publish(_ nextViewState: RideDashboardViewState) {
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }

    private func startConnectionStabilityPeriod() {
        guard connectionStabilityTask == nil else { return }
        let stabilityPeriod = initialConnectionStabilityPeriod
        let timing = timing
        connectionStabilityTask = Task { [weak self] in
            do {
                try await timing.sleep(stabilityPeriod)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.promoteStableConnection()
        }
    }

    private func promoteStableConnection() {
        connectionStabilityTask = nil
        guard let pendingLiveViewState, isReceivingTelemetry else {
            self.pendingLiveViewState = nil
            render()
            return
        }
        self.pendingLiveViewState = nil
        let liveViewState = pendingLiveViewState.withContinuity(.live)
        lastLiveViewState = liveViewState
        lastLivePowerModeIndex = snapshot.telemetry.mode.displayIndex
        publish(liveViewState)
    }

    private func cancelPendingConnectionStability() {
        connectionStabilityTask?.cancel()
        connectionStabilityTask = nil
        pendingLiveViewState = nil
    }

    private func startReconnectionNoticeDelay() {
        guard reconnectionNoticeTask == nil, !isShowingReconnectionNotice else { return }
        let noticeDelay = reconnectionNoticeDelay
        let timing = timing
        let generation = reconnectionNoticeGeneration
        reconnectionNoticeTask = Task { [weak self] in
            do {
                try await timing.sleep(noticeDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.showReconnectionNotice(generation: generation)
        }
    }

    private func showReconnectionNotice(generation: Int) {
        guard generation == reconnectionNoticeGeneration,
              let lastLiveViewState,
              continuityPolicy.phase(
                connectionState: snapshot.connection.state,
                hasLiveTelemetry: false,
                hasValidPresentation: true
              ) == .recovering else {
            return
        }
        reconnectionNoticeTask = nil
        isShowingReconnectionNotice = true
        publish(lastLiveViewState.withContinuity(
            .recovering,
            notice: DashboardConnectionNoticeViewData()
        ))
    }

    private func cancelReconnectionNotice() {
        reconnectionNoticeGeneration &+= 1
        reconnectionNoticeTask?.cancel()
        reconnectionNoticeTask = nil
        isShowingReconnectionNotice = false
    }

    private func updateStatusSnapshotRefresh() {
        guard isReceivingTelemetry else {
            statusSnapshotRefreshTask?.cancel()
            statusSnapshotRefreshTask = nil
            didRefreshStatusForTelemetrySession = false
            return
        }
        guard !didRefreshStatusForTelemetrySession else { return }
        didRefreshStatusForTelemetrySession = true

        let vehicleSession = vehicleSession
        statusSnapshotRefreshTask = Task {
            await vehicleSession.refreshBikeStatus()
        }
    }

    private var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = snapshot.connection.state {
            true
        } else {
            false
        }
    }

    private func livePresentation(from mappedViewState: RideDashboardViewState) -> RideDashboardViewState {
        let modeIndex = snapshot.telemetry.mode.displayIndex
        let preservedPowerMode: DashboardPowerModeViewData?
        if modeIndex == lastLivePowerModeIndex,
           !mappedViewState.powerMode.isVisible,
           lastLiveViewState?.powerMode.isVisible == true {
            preservedPowerMode = lastLiveViewState?.powerMode
        } else {
            preservedPowerMode = nil
        }
        return mappedViewState.withContinuity(.live, powerMode: preservedPowerMode)
    }

    private func updateVehicleIdentity() {
        guard let identity = snapshotVehicleIdentity else { return }
        guard let cachedVehicleIdentity else {
            self.cachedVehicleIdentity = identity
            return
        }
        guard cachedVehicleIdentity != identity else { return }
        self.cachedVehicleIdentity = identity
        cancelPendingConnectionStability()
        cancelReconnectionNotice()
        didRefreshStatusForTelemetrySession = false
        clearCachedPresentation()
    }

    private var snapshotVehicleIdentity: String? {
        if let vin = snapshot.profile?.vin { return vin }
        return switch snapshot.connection.state {
        case .scanning(let vin), .connecting(let vin, _), .reconnecting(let vin, _, _): vin
        default: nil
        }
    }

    private func clearCachedPresentation() {
        lastLiveViewState = nil
        lastLivePowerModeIndex = nil
    }

    private func setTemperatureMonitoringRequired(_ required: Bool) {
        guard required != isRequestingTemperatureMonitoring else { return }
        isRequestingTemperatureMonitoring = required
        let previousRequest = temperatureMonitoringTask
        let vehicleSession = vehicleSession
        let consumerID = temperatureMonitoringConsumerID
        temperatureMonitoringTask = Task {
            await previousRequest?.value
            guard !Task.isCancelled else { return }
            await vehicleSession.setBatteryHealthMonitoringRequired(required, consumerID: consumerID)
        }
    }
}
