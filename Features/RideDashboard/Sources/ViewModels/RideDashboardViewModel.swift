import BikeDomain
import Combine
import Foundation
import RuntimeConfiguration
import VehicleSession

@MainActor
public final class RideDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = RideDashboardViewState()

    private let mapper: RideDashboardMapper
    private let vehicleSession: any VehicleSessionService
    private var snapshot = VehicleSessionSnapshot()
    private var observationTask: Task<Void, Never>?
    private var statusSnapshotRefreshTask: Task<Void, Never>?
    private var reconnectionGraceTask: Task<Void, Never>?
    private var lastLiveViewState: RideDashboardViewState?
    private let reconnectionGracePeriod: Duration

    public init(
        mapper: RideDashboardMapper,
        vehicleSession: any VehicleSessionService,
        reconnectionGracePeriod: Duration
    ) {
        self.mapper = mapper
        self.vehicleSession = vehicleSession
        self.reconnectionGracePeriod = reconnectionGracePeriod
    }

    deinit {
        observationTask?.cancel()
        statusSnapshotRefreshTask?.cancel()
        reconnectionGraceTask?.cancel()
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
        reconnectionGraceTask?.cancel()
        reconnectionGraceTask = nil
        lastLiveViewState = nil
    }

#if DEBUG
    func setPreviewState(_ viewState: RideDashboardViewState) {
        self.viewState = viewState
    }
#endif

    private func render() {
        let mappedViewState = mapper.map(
            telemetry: snapshot.telemetry,
            connection: snapshot.connection,
            speedKilometersPerHour: snapshot.resolvedSpeedKilometersPerHour,
            speedSource: snapshot.speedSource,
            progressBarMode: snapshot.settings.dashboardProgressBarMode,
            batteryIndicatorMode: snapshot.settings.dashboardBatteryIndicatorMode,
            showsTemperatures: snapshot.settings.showsDashboardTemperatures,
            measurementSystem: snapshot.settings.measurementSystem,
            isGPSAvailable: snapshot.isGPSAvailable
        )
        updateViewState(with: mappedViewState)
        updateStatusSnapshotRefresh()
    }

    private func updateViewState(with mappedViewState: RideDashboardViewState) {
        if mappedViewState.hasTelemetry {
            reconnectionGraceTask?.cancel()
            reconnectionGraceTask = nil
            lastLiveViewState = mappedViewState
            publish(mappedViewState)
            return
        }

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
            return
        }
        guard statusSnapshotRefreshTask == nil else { return }

        let vehicleSession = vehicleSession
        statusSnapshotRefreshTask = Task {
            while !Task.isCancelled {
                await vehicleSession.refreshBikeStatus()
                do {
                    try await Task.sleep(for: Constants.statusSnapshotRefreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    private var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = snapshot.connection.state {
            true
        } else {
            false
        }
    }

    private enum Constants {
        static let statusSnapshotRefreshInterval = FENRRuntimeConstants.Telemetry.statusSnapshotRefreshInterval
    }
}
