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
    private let temperatureMonitoringConsumerID = UUID()
    private var snapshot = VehicleSessionSnapshot()
    private var observationTask: Task<Void, Never>?
    private var temperatureMonitoringTask: Task<Void, Never>?
    private var isRequestingTemperatureMonitoring = false
    private var statusSnapshotRefreshTask: Task<Void, Never>?
    private var didRefreshStatusForTelemetrySession = false
    private var connectionStabilityTask: Task<Void, Never>?
    private var reconnectionGraceTask: Task<Void, Never>?
    private var pendingLiveViewState: RideDashboardViewState?
    private var lastLiveViewState: RideDashboardViewState?
    private let initialConnectionStabilityPeriod: Duration
    private let reconnectionGracePeriod: Duration

    public init(
        mapper: RideDashboardMapper,
        cardLayoutMapper: DashboardCardLayoutMapper,
        vehicleSession: any VehicleSessionService,
        initialConnectionStabilityPeriod: Duration,
        reconnectionGracePeriod: Duration
    ) {
        self.mapper = mapper
        self.cardLayoutMapper = cardLayoutMapper
        self.vehicleSession = vehicleSession
        self.initialConnectionStabilityPeriod = initialConnectionStabilityPeriod
        self.reconnectionGracePeriod = reconnectionGracePeriod
    }

    deinit {
        observationTask?.cancel()
        statusSnapshotRefreshTask?.cancel()
        connectionStabilityTask?.cancel()
        reconnectionGraceTask?.cancel()
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

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
        statusSnapshotRefreshTask?.cancel()
        statusSnapshotRefreshTask = nil
        didRefreshStatusForTelemetrySession = false
        cancelPendingConnectionStability()
        reconnectionGraceTask?.cancel()
        reconnectionGraceTask = nil
        lastLiveViewState = nil
        setTemperatureMonitoringRequired(false)
    }

#if DEBUG
    func setPreviewState(_ viewState: RideDashboardViewState) {
        self.viewState = viewState
    }
#endif

    private func render() {
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
            showsTemperatures: snapshot.settings.showsDashboardTemperatures,
            measurementSystem: snapshot.settings.measurementSystem,
            isGPSAvailable: snapshot.isGPSAvailable,
            powerModeNames: snapshot.settings.powerModeNames(forVIN: snapshot.profile?.vin)
        )
        updateViewState(with: mappedViewState)
        updateStatusSnapshotRefresh()
        setTemperatureMonitoringRequired(snapshot.settings.showsDashboardTemperatures)
    }

    private func updateViewState(with mappedViewState: RideDashboardViewState) {
        if mappedViewState.hasTelemetry {
            if lastLiveViewState == nil {
                pendingLiveViewState = mappedViewState
                publish(mappedViewState.waitingForStableTelemetry())
                startConnectionStabilityPeriod()
                return
            }
            cancelPendingConnectionStability()
            reconnectionGraceTask?.cancel()
            reconnectionGraceTask = nil
            lastLiveViewState = mappedViewState
            publish(mappedViewState)
            return
        }

        cancelPendingConnectionStability()

        guard
            isTransientReconnectionState(snapshot.connection.state),
            let lastLiveViewState
        else {
            reconnectionGraceTask?.cancel()
            reconnectionGraceTask = nil
            self.lastLiveViewState = nil
            publish(mappedViewState)
            return
        }

        publish(lastLiveViewState)
        startReconnectionGracePeriod()
    }

    private func publish(_ nextViewState: RideDashboardViewState) {
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }

    private func startConnectionStabilityPeriod() {
        guard connectionStabilityTask == nil else { return }
        let stabilityPeriod = initialConnectionStabilityPeriod
        connectionStabilityTask = Task { [weak self] in
            do {
                try await Task.sleep(for: stabilityPeriod)
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
        lastLiveViewState = pendingLiveViewState
        publish(pendingLiveViewState)
    }

    private func cancelPendingConnectionStability() {
        connectionStabilityTask?.cancel()
        connectionStabilityTask = nil
        pendingLiveViewState = nil
    }

    private func startReconnectionGracePeriod() {
        guard reconnectionGraceTask == nil else { return }
        let gracePeriod = reconnectionGracePeriod
        reconnectionGraceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: gracePeriod)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.expireReconnectionGracePeriod()
        }
    }

    private func expireReconnectionGracePeriod() {
        reconnectionGraceTask = nil
        lastLiveViewState = nil
        render()
    }

    private func isTransientReconnectionState(_ state: ConnectionState) -> Bool {
        switch state {
        case .scanning, .connecting, .discovering, .authenticating, .authenticated, .subscribed, .reconnecting,
             .disconnected:
            true
        case .idle, .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff, .receivingTelemetry,
             .pairingResetRequired, .failed:
            false
        }
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
