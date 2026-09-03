import BikeDomain
import BLETraceDomain
import Foundation
import SettingsDomain
import VehicleSession

@MainActor
public final class BikeDiagnosticsViewModel: ObservableObject {
    @Published public private(set) var viewState = BikeDiagnosticsViewState()
    @Published public private(set) var bleTraceExport: BLETraceExportViewData?
    @Published public private(set) var isPresentationActive = false

    private let useCases: BikeDiagnosticsUseCases
    private var mappers: BikeDiagnosticsMappers
    private let makeMappers: (MeasurementSystem) -> BikeDiagnosticsMappers
    private var sessionSnapshot = VehicleSessionSnapshot()
    private var debugLogEvents: [BikeDebugEvent] = []
    private var bleTraceSessions: [BLETraceSessionSummary] = []
    private var bleTraceError: String?
    private var observationTasks: [Task<Void, Never>] = []
    private var actionTask: Task<Void, Never>?
    private var bleTraceActionTask: Task<Void, Never>?

    public init(
        useCases: BikeDiagnosticsUseCases,
        mappers: BikeDiagnosticsMappers,
        makeMappers: @escaping (MeasurementSystem) -> BikeDiagnosticsMappers
    ) {
        self.useCases = useCases
        self.mappers = mappers
        self.makeMappers = makeMappers
        render()
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        actionTask?.cancel()
        bleTraceActionTask?.cancel()
    }

    /// Controls feature observation only. The app owns the shared vehicle session lifecycle.
    /// Keep this true while any destination in the Diagnostics family is visible.
    public func setPresentationActive(_ active: Bool) {
        guard active != isPresentationActive else { return }
        isPresentationActive = active
        if active {
            bindStreams()
        } else {
            cancelObservationTasks()
        }
    }

    public func reconnectTapped() {
        guard let vin = sessionSnapshot.profile?.vin, !vin.isEmpty else { return }
        let connect = useCases.connect
        performAction { try await connect.execute(vin: vin) }
    }

    public func disconnectTapped() {
        let disconnect = useCases.disconnect
        performAction { try await disconnect.execute() }
    }

    public func pairRetryTapped() {
        let retry = useCases.retrySecurityHandshake
        performAction { try await retry.execute() }
    }

    public func readSnapshotTapped() {
        let session = useCases.session
        performAction { await session.refreshBikeStatus() }
    }

    public func clearDebugEvents() {
        debugLogEvents.removeAll()
        render()
    }

    public func debugLogText() -> String {
        mappers.viewState.exportDebugLog(sessionSnapshot, events: debugLogEvents)
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
                guard !Task.isCancelled else { return }
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
        let session = useCases.session
        observationTasks.append(Task { [weak self] in
            let stream = await session.observe()
            for await snapshot in stream where !Task.isCancelled {
                self?.receive(snapshot)
            }
        })

        let observeDebugEvents = useCases.observeDebugEvents
        observationTasks.append(Task { [weak self] in
            let stream = await observeDebugEvents.execute()
            for await event in stream where !Task.isCancelled {
                self?.appendDebugEvent(event)
            }
        })

        let observeBLETraceSessions = useCases.observeBLETraceSessions
        observationTasks.append(Task { [weak self] in
            let stream = await observeBLETraceSessions.execute()
            for await sessions in stream where !Task.isCancelled {
                self?.bleTraceSessions = sessions
                self?.render()
            }
        })
    }

    private func receive(_ snapshot: VehicleSessionSnapshot) {
        let measurementSystemChanged = sessionSnapshot.settings.measurementSystem
            != snapshot.settings.measurementSystem
        sessionSnapshot = snapshot
        if measurementSystemChanged {
            mappers = makeMappers(snapshot.settings.measurementSystem)
        }
        render()
    }

    private func performAction(_ operation: @escaping @Sendable () async throws -> Void) {
        actionTask?.cancel()
        actionTask = Task { @MainActor [weak self] in
            do {
                try await operation()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.appendDebugError(error)
            }
        }
    }

    private func appendDebugError(_ error: Error) {
        appendDebugEvent(BikeDebugEvent(
            title: BikeDiagnosticsL10n.text(.bikeDiagnosticsDebugErrorTitle),
            detail: String(describing: error)
        ))
    }

    private func appendDebugEvent(_ event: BikeDebugEvent) {
        debugLogEvents.insert(event, at: .zero)
        debugLogEvents = Array(
            debugLogEvents.prefix(BikeDiagnosticsConstants.maxExportDebugEvents)
        )
        render()
    }

    private func render() {
        var nextViewState = mappers.viewState.map(
            sessionSnapshot,
            debugEvents: visibleDebugEvents()
        )
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
                guard !Task.isCancelled else { return }
                self?.bleTraceError = BikeDiagnosticsL10n.text(.bikeDiagnosticsBleLogOperationError)
                self?.render()
            }
        }
    }

    private func cancelObservationTasks() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
    }

    private func visibleDebugEvents() -> [BikeDebugEvent] {
        var identifiers = Set<UUID>()
        return Array(
            debugLogEvents
                .filter { identifiers.insert($0.id).inserted }
                .prefix(BikeDiagnosticsConstants.maxVisibleDebugEvents)
        )
    }
}
