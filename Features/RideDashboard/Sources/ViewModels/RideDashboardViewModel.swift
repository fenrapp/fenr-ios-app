import BikeDomain
import Combine
import EnvironmentDomain
import RuntimeConfiguration
import SettingsDomain

@MainActor
public final class RideDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = RideDashboardViewState()

    private let useCases: RideDashboardUseCases
    private let mapper: RideDashboardMapper
    private var telemetry = BikeTelemetry()
    private var connection = BikeConnection()
    private var settings = AppSettings()
    private var deviceSpeedSample: DeviceSpeedSample?
    private var tasks: [Task<Void, Never>] = []
    private var deviceSpeedTask: Task<Void, Never>?
    private var statusSnapshotRefreshTask: Task<Void, Never>?
    private var reconnectionGraceTask: Task<Void, Never>?
    private var lastLiveViewState: RideDashboardViewState?
    private let reconnectionGracePeriod: Duration

    public init(
        useCases: RideDashboardUseCases,
        mapper: RideDashboardMapper = .init(),
        reconnectionGracePeriod: Duration = FENRRuntimeConstants.RideDashboard.reconnectionGracePeriod
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.reconnectionGracePeriod = reconnectionGracePeriod
    }

    deinit {
        tasks.forEach { $0.cancel() }
        deviceSpeedTask?.cancel()
        statusSnapshotRefreshTask?.cancel()
        reconnectionGraceTask?.cancel()
    }

    public func startObserving() {
        guard tasks.isEmpty else { return }
        let observeTelemetry = useCases.observeTelemetry
        tasks.append(Task { [weak self] in
            let stream = await observeTelemetry.execute()
            for await telemetry in stream {
                guard !Task.isCancelled else { return }
                self?.telemetry = telemetry
                self?.render()
            }
        })
        let observeConnection = useCases.observeConnection
        tasks.append(Task { [weak self] in
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.connection = connection
                self?.render()
            }
        })
        let observeSettings = useCases.observeSettings
        tasks.append(Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.settings = settings
                self?.render()
            }
        })
    }

    public func stopObserving() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        deviceSpeedTask?.cancel()
        deviceSpeedTask = nil
        statusSnapshotRefreshTask?.cancel()
        statusSnapshotRefreshTask = nil
        deviceSpeedSample = nil
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
            telemetry: telemetry,
            connection: connection,
            speedKilometersPerHour: DeviceSpeedResolver().resolvedSpeed(
                motorcycleKilometersPerHour: telemetry.speed.kmh,
                deviceSample: deviceSpeedSample,
                source: settings.speedSource
            ),
            measurementSystem: settings.measurementSystem
        )
        updateViewState(with: mappedViewState)
        updateDeviceSpeedObservation()
        updateStatusSnapshotRefresh()
    }

    private func updateViewState(with mappedViewState: RideDashboardViewState) {
        if mappedViewState.hasTelemetry {
            reconnectionGraceTask?.cancel()
            reconnectionGraceTask = nil
            lastLiveViewState = mappedViewState
            viewState = mappedViewState
            return
        }

        guard
            isTransientReconnectionState(connection.state),
            let lastLiveViewState
        else {
            reconnectionGraceTask?.cancel()
            reconnectionGraceTask = nil
            self.lastLiveViewState = nil
            viewState = mappedViewState
            return
        }

        viewState = lastLiveViewState
        startReconnectionGracePeriod()
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
             .failed:
            false
        }
    }

    private func updateDeviceSpeedObservation() {
        guard settings.speedSource.usesDeviceLocation, deviceSpeedTask == nil else {
            if !settings.speedSource.usesDeviceLocation {
                deviceSpeedTask?.cancel()
                deviceSpeedTask = nil
                deviceSpeedSample = nil
            }
            return
        }
        let observeDeviceSpeed = useCases.observeDeviceSpeed
        deviceSpeedTask = Task { [weak self] in
            let stream = await observeDeviceSpeed.execute()
            for await sample in stream {
                guard !Task.isCancelled else { return }
                self?.deviceSpeedSample = sample
                self?.render()
            }
        }
    }

    private func updateStatusSnapshotRefresh() {
        guard isReceivingTelemetry else {
            statusSnapshotRefreshTask?.cancel()
            statusSnapshotRefreshTask = nil
            return
        }
        guard statusSnapshotRefreshTask == nil else { return }

        let readBikeStatusSnapshot = useCases.readBikeStatusSnapshot
        statusSnapshotRefreshTask = Task {
            while !Task.isCancelled {
                try? await readBikeStatusSnapshot.execute()
                do {
                    try await Task.sleep(for: Constants.statusSnapshotRefreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    private var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = connection.state {
            true
        } else {
            false
        }
    }

    private enum Constants {
        static let statusSnapshotRefreshInterval = FENRRuntimeConstants.Telemetry.statusSnapshotRefreshInterval
    }
}
