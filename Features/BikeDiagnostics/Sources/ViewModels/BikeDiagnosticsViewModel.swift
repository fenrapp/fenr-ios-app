import BikeDomain
import Foundation
import SettingsDomain

@MainActor
public final class BikeDiagnosticsViewModel: ObservableObject {
    @Published public private(set) var viewState = BikeDiagnosticsViewState()

    private let useCases: BikeDiagnosticsUseCases
    private var mappers: BikeDiagnosticsMappers
    private let makeMappers: (MeasurementSystem) -> BikeDiagnosticsMappers
    private var snapshot = BikeDiagnosticsDomainSnapshot()
    private var debugLogEvents: [BikeDebugEvent] = []
    private var streamTasks: [Task<Void, Never>] = []
    private var lifecycleTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var isStarted = false

    public init(
        useCases: BikeDiagnosticsUseCases,
        mappers: BikeDiagnosticsMappers,
        makeMappers: @escaping (MeasurementSystem) -> BikeDiagnosticsMappers
    ) {
        self.useCases = useCases
        self.mappers = mappers
        self.makeMappers = makeMappers
    }

    deinit {
        streamTasks.forEach { $0.cancel() }
        lifecycleTask?.cancel()
        actionTask?.cancel()
    }

    public func start() {
        startObserving()
        lifecycleTask?.cancel()
        let start = useCases.start
        lifecycleTask = Task { await start.execute() }
    }

    public func stop() {
        stopObserving()
        lifecycleTask?.cancel()
        let stop = useCases.stop
        lifecycleTask = Task { await stop.execute() }
    }

    public func startObserving() {
        guard !isStarted else { return }
        isStarted = true
        bindStreams()
        render()
        restoreProfileIfNeeded()
    }

    public func stopObserving() {
        guard isStarted else { return }
        isStarted = false
        cancelStreamTasks()
    }

    public func vinChanged(_ vin: String) {
        snapshot.vin = vin.uppercased()
        snapshot.pin = snapshot.vin.isEmpty
            ? BikeDiagnosticsText.placeholderPIN
            : useCases.derivePin.execute(vin: snapshot.vin)
        render()
    }

    public func connectTapped() {
        let vin = snapshot.vin.trimmingCharacters(in: .whitespacesAndNewlines)
        let connect = useCases.connect
        performAction {
            try await connect.execute(vin: vin)
        }
    }

    public func disconnectTapped() {
        let disconnect = useCases.disconnect
        performAction {
            try await disconnect.execute()
        }
    }

    public func pairRetryTapped() {
        let retrySecurityHandshake = useCases.retrySecurityHandshake
        performAction {
            try await retrySecurityHandshake.execute()
        }
    }

    public func readSnapshotTapped() {
        let readTelemetrySnapshot = useCases.readTelemetrySnapshot
        performAction {
            try await readTelemetrySnapshot.execute()
        }
    }

    public func debugLogText() -> String {
        mappers.viewState.exportDebugLog(debugLogEvents)
    }

    private func bindStreams() {
        let observeTelemetry = useCases.observeTelemetry
        streamTasks.append(Task { [weak self] in
            let stream = await observeTelemetry.execute()
            for await telemetry in stream {
                guard !Task.isCancelled else { return }
                self?.receive(telemetry)
            }
        })
        let observeConnection = useCases.observeConnection
        streamTasks.append(Task { [weak self] in
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.receive(connection)
            }
        })
        let observeDebugEvents = useCases.observeDebugEvents
        streamTasks.append(Task { [weak self] in
            let stream = await observeDebugEvents.execute()
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.receive(event)
            }
        })
        let observeSettings = useCases.observeSettings
        streamTasks.append(Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.mappers = self.makeMappers(settings.measurementSystem)
                self.render()
            }
        })
    }

    private func performAction(
        _ operation: @escaping @Sendable () async throws -> Void,
        onSuccess: (@MainActor @Sendable () -> Void)? = nil
    ) {
        actionTask?.cancel()
        actionTask = Task { @MainActor [weak self] in
            do {
                try await operation()
                onSuccess?()
            } catch is CancellationError {
                return
            } catch {
                self?.appendDebugError(error)
            }
        }
    }

    private func restoreProfileIfNeeded() {
        let loadProfile = useCases.loadProfile
        Task { [weak self] in
            guard let profile = await loadProfile.execute() else { return }
            self?.vinChanged(profile.vin)
        }
    }

    private func receive(_ telemetry: BikeTelemetry) {
        snapshot.telemetry = telemetry
        render()
    }

    private func receive(_ connection: BikeConnection) {
        snapshot.connection = connection
        render()
    }

    private func receive(_ event: BikeDebugEvent) {
        appendDebugEvent(event)
    }

    private func appendDebugError(_ error: Error) {
        appendDebugEvent(BikeDebugEvent(title: "Error", detail: String(describing: error)))
    }

    private func appendDebugEvent(_ event: BikeDebugEvent) {
        debugLogEvents.insert(event, at: .zero)
        debugLogEvents = Array(debugLogEvents.prefix(BikeDiagnosticsConstants.maxExportDebugEvents))
        if let existingIndex = snapshot.debugEvents.firstIndex(where: { $0.id == event.id }) {
            snapshot.debugEvents.remove(at: existingIndex)
        }
        snapshot.debugEvents.insert(event, at: .zero)
        snapshot.debugEvents = Array(snapshot.debugEvents.prefix(BikeDiagnosticsConstants.maxVisibleDebugEvents))
        render()
    }

    private func render() {
        let nextViewState = mappers.viewState.map(snapshot)
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }

    private func cancelStreamTasks() {
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
    }

}
