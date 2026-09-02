import BikeDomain
import BLETraceDomain
import Foundation
import SettingsDomain

@MainActor
public final class BikeDiagnosticsViewModel: ObservableObject {
    @Published public private(set) var viewState = BikeDiagnosticsViewState()
    @Published public private(set) var bleTraceExport: BLETraceExportViewData?

    private let useCases: BikeDiagnosticsUseCases
    private var mappers: BikeDiagnosticsMappers
    private let makeMappers: (MeasurementSystem) -> BikeDiagnosticsMappers
    private var snapshot = BikeDiagnosticsDomainSnapshot()
    private var debugLogEvents: [BikeDebugEvent] = []
    private var bleTraceSessions: [BLETraceSessionSummary] = []
    private var bleTraceError: String?
    private var streamTasks: [Task<Void, Never>] = []
    private var lifecycleTask: Task<Void, Never>?
    private var actionTask: Task<Void, Never>?
    private var profileRestoreTask: Task<Void, Never>?
    private var bleTraceActionTask: Task<Void, Never>?
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
        profileRestoreTask?.cancel()
        bleTraceActionTask?.cancel()
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
        profileRestoreTask?.cancel()
        profileRestoreTask = nil
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
        mappers.viewState.exportDebugLog(snapshot, events: debugLogEvents)
    }

    public func exportBLETraceSession(id: UUID) {
        bleTraceActionTask?.cancel()
        let prepareExport = useCases.prepareBLETraceExport
        bleTraceActionTask = Task { @MainActor [weak self] in
            do {
                let url = try await prepareExport.execute(sessionID: id)
                guard !Task.isCancelled else { return }
                self?.bleTraceError = nil
                self?.bleTraceExport = BLETraceExportViewData(id: id, fileURL: url)
                self?.render()
            } catch is CancellationError {
                return
            } catch {
                self?.bleTraceError = BikeDiagnosticsL10n.text(.bikeDiagnosticsBleLogPrepareError)
                self?.render()
            }
        }
    }

    public func deleteBLETraceSession(id: UUID) {
        performBLETraceAction { [useCases] in
            try await useCases.deleteBLETraceSession.execute(sessionID: id)
        }
    }

    public func deleteAllBLETraceSessions() {
        performBLETraceAction { [useCases] in
            try await useCases.deleteAllBLETraceSessions.execute()
        }
    }

    public func clearBLETraceExport() {
        bleTraceExport = nil
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
        let observeBLETraceSessions = useCases.observeBLETraceSessions
        streamTasks.append(Task { [weak self] in
            let stream = await observeBLETraceSessions.execute()
            for await sessions in stream {
                guard !Task.isCancelled else { return }
                self?.bleTraceSessions = sessions
                self?.render()
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
        profileRestoreTask?.cancel()
        let loadProfile = useCases.loadProfile
        profileRestoreTask = Task { [weak self] in
            guard let profile = await loadProfile.execute() else { return }
            guard !Task.isCancelled else { return }
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
        appendDebugEvent(BikeDebugEvent(
            title: BikeDiagnosticsL10n.text(.bikeDiagnosticsDebugErrorTitle),
            detail: String(describing: error)
        ))
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
        var nextViewState = mappers.viewState.map(snapshot)
        nextViewState.bleTraceSessions = bleTraceSessions.map(mappers.bleTraceSession.map)
        nextViewState.bleTraceError = bleTraceError
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }

    private func performBLETraceAction(
        _ operation: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        bleTraceActionTask?.cancel()
        bleTraceActionTask = Task { @MainActor [weak self] in
            do {
                try await operation()
                guard !Task.isCancelled else { return }
                self?.bleTraceError = nil
                self?.render()
            } catch is CancellationError {
                return
            } catch {
                self?.bleTraceError = BikeDiagnosticsL10n.text(.bikeDiagnosticsBleLogOperationError)
                self?.render()
            }
        }
    }

    private func cancelStreamTasks() {
        streamTasks.forEach { $0.cancel() }
        streamTasks.removeAll()
    }
}
