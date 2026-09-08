import BikeDomain
import Foundation
import Observation
import SettingsDomain
import VehicleSession

@MainActor
@Observable
public final class RideDashboardViewModel {
    public private(set) var viewState = RideDashboardViewState()
    private(set) var cardLayout = DashboardCardLayout()

    private let onContinuityChanged: @MainActor (RideDashboardContinuityPhase) -> Void
    private let mapper: RideDashboardMapper
    private let cardLayoutMapper: DashboardCardLayoutMapper
    private let vehicleSession: any VehicleSessionService
    private let timing: RideDashboardTiming
    private let continuityPolicy: RideDashboardContinuityPolicy
    private let temperatureMonitoringConsumerID = UUID()
    @ObservationIgnored private var snapshot = VehicleSessionSnapshot()
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var temperatureMonitoringTask: Task<Void, Never>?
    @ObservationIgnored private var isRequestingTemperatureMonitoring = false
    @ObservationIgnored private var statusSnapshotRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var didRefreshStatusForTelemetrySession = false
    @ObservationIgnored private var connectionStabilityTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectionNoticeTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectionNoticeGeneration = 0
    @ObservationIgnored private var isShowingReconnectionNotice = false
    @ObservationIgnored private var pendingLiveViewState: RideDashboardViewState?
    @ObservationIgnored private var lastLiveViewState: RideDashboardViewState?
    @ObservationIgnored private var lastLivePowerModeIndex: Int?
    @ObservationIgnored private var cachedVehicleIdentity: String?
    @ObservationIgnored private var measurementCache =
        DashboardPresentationCache<RideDashboardMappingInput.Configuration, RideDashboardMeasurementMapper>()
    @ObservationIgnored private var presentationCache =
        DashboardPresentationCache<RideDashboardMappingInput, RideDashboardViewState>()
    @ObservationIgnored private var layoutCache =
        DashboardPresentationCache<DashboardCardConfiguration, DashboardCardLayout>()
    private let initialConnectionStabilityPeriod: Duration
    private let reconnectionNoticeDelay: Duration

    public init(
        mapper: RideDashboardMapper,
        cardLayoutMapper: DashboardCardLayoutMapper,
        vehicleSession: any VehicleSessionService,
        timing: RideDashboardTiming,
        continuityPolicy: RideDashboardContinuityPolicy,
        initialConnectionStabilityPeriod: Duration,
        reconnectionNoticeDelay: Duration,
        onContinuityChanged: @escaping @MainActor (RideDashboardContinuityPhase) -> Void
    ) {
        self.onContinuityChanged = onContinuityChanged
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
        measurementCache = .init()
        presentationCache = .init()
        layoutCache = .init()
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
        publish(viewState)
    }
}
#endif

private extension RideDashboardViewModel {
    func render() {
        updateVehicleIdentity()
        let nextCardLayout = layoutCache.value(for: snapshot.settings.dashboardCardConfiguration) {
            cardLayoutMapper.map(snapshot.settings.dashboardCardConfiguration)
        }
        if nextCardLayout != cardLayout {
            cardLayout = nextCardLayout
        }
        let input = RideDashboardMappingInput(snapshot: snapshot)
        let measurementMapper = measurementCache.value(for: input.configuration) {
            mapper.measurementMapper(for: input.configuration.measurementSystem)
        }
        let mappedViewState = presentationCache.value(for: input) {
            input.map(using: mapper, measurementMapper: measurementMapper)
        }
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
        let phaseChanged = viewState.continuityPhase != nextViewState.continuityPhase
        viewState = nextViewState
        if phaseChanged { onContinuityChanged(nextViewState.continuityPhase) }
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
        guard let pendingLiveViewState, case .receivingTelemetry = snapshot.connection.state else {
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
        guard case .receivingTelemetry = snapshot.connection.state else {
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

    private func livePresentation(from mappedViewState: RideDashboardViewState) -> RideDashboardViewState {
        let modeIndex = snapshot.telemetry.mode.displayIndex
        let preservedPowerMode: DashboardPowerModeViewData?
        if snapshot.telemetry.runState == .on,
           modeIndex == lastLivePowerModeIndex,
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
