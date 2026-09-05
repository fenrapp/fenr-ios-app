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
    private let bleTraceCaptureConfirmationTimeout: Duration
    private var mappers: BikeDiagnosticsMappers
    private let makeMappers: (MeasurementSystem) -> BikeDiagnosticsMappers
    private var sessionSnapshot = VehicleSessionSnapshot()
    private var debugLogEvents: [BikeDebugEvent] = []
    private var bleTraceSessions: [BLETraceSessionSummary] = []
    private var bleTraceError: String?
    private var isBLETraceCaptureControlInProgress = false
    private var observationTasks: [Task<Void, Never>] = []
    private var actionTask: Task<Void, Never>?
    private var bleTraceActionTask: Task<Void, Never>?
    private var bleTraceActionGeneration: UInt64 = 0
    private var bleTraceCaptureControlTask: Task<Void, Never>?
    private var bleTraceCaptureControlGeneration: UInt64 = 0
    private var pendingBLETraceCaptureExpectation: BLETraceCaptureExpectation?

    public init(
        useCases: BikeDiagnosticsUseCases,
        mappers: BikeDiagnosticsMappers,
        makeMappers: @escaping (MeasurementSystem) -> BikeDiagnosticsMappers,
        bleTraceCaptureConfirmationTimeout: Duration
    ) {
        self.useCases = useCases
        self.mappers = mappers
        self.makeMappers = makeMappers
        self.bleTraceCaptureConfirmationTimeout = bleTraceCaptureConfirmationTimeout
        render()
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        actionTask?.cancel()
        bleTraceActionTask?.cancel()
        bleTraceCaptureControlTask?.cancel()
    }

    /// Controls feature observation only. The app owns the shared vehicle session lifecycle.
    /// Keep this true while any destination in the Diagnostics family is visible.
    public func setPresentationActive(_ active: Bool) {
        guard active != isPresentationActive else { return }
        isPresentationActive = active
        if active {
            bindStreams()
        } else {
            cancelBLETraceCaptureControl()
            cancelObservationTasks()
        }
    }

    public func stopAndWait() async {
        let tasks = observationTasks + [actionTask, bleTraceActionTask, bleTraceCaptureControlTask].compactMap { $0 }
        tasks.forEach { $0.cancel() }
        setPresentationActive(false)
        for task in tasks { await task.value }
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
        guard bleTraceCaptureControlTask == nil else { return }
        bleTraceActionTask?.cancel()
        bleTraceActionGeneration &+= 1
        let generation = bleTraceActionGeneration
        let prepareExport = useCases.prepareBLETraceExport
        bleTraceActionTask = Task { @MainActor [weak self] in
            defer { self?.completeBLETraceAction(generation: generation) }
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
        guard bleTraceCaptureControlTask == nil else { return }
        performBLETraceAction { [useCases] in
            try await useCases.deleteBLETraceSession.execute(sessionID: id)
        }
    }

    public func deleteAllBLETraceSessions() {
        guard bleTraceCaptureControlTask == nil else { return }
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
                self?.receiveBLETraceSessions(sessions)
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
        nextViewState.isBLETraceCaptureControlInProgress = isBLETraceCaptureControlInProgress
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }

    private func performBLETraceAction(
        _ operation: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        bleTraceActionTask?.cancel()
        bleTraceActionGeneration &+= 1
        let generation = bleTraceActionGeneration
        bleTraceActionTask = Task { @MainActor [weak self] in
            defer { self?.completeBLETraceAction(generation: generation) }
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

    private func completeBLETraceAction(generation: UInt64) {
        guard bleTraceActionGeneration == generation else { return }
        bleTraceActionTask = nil
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

extension BikeDiagnosticsViewModel {
    public func toggleBLETraceCapture() {
        guard bleTraceCaptureControlTask == nil, bleTraceActionTask == nil else { return }
        let isRecording = bleTraceSessions.contains { $0.status == .active }
        guard isRecording || viewState.isDisconnectEnabled else { return }

        isBLETraceCaptureControlInProgress = true
        bleTraceCaptureControlGeneration &+= 1
        let generation = bleTraceCaptureControlGeneration
        let expectation = BLETraceCaptureExpectation(isActive: !isRecording)
        render()
        let startCapture = useCases.startNewDiagnosticsCapture
        let stopCapture = useCases.stopDiagnosticsCapture
        bleTraceCaptureControlTask = Task { @MainActor [weak self] in
            let succeeded = if isRecording {
                await stopCapture.execute()
            } else {
                await startCapture.execute()
            }
            guard let self, !Task.isCancelled else { return }
            if !succeeded {
                completeBLETraceCaptureControl(generation: generation, didFail: true)
                return
            }
            pendingBLETraceCaptureExpectation = expectation
            if expectation.matches(bleTraceSessions) {
                completeBLETraceCaptureControl(generation: generation, didFail: false)
                return
            }
            render()
            do {
                try await Task.sleep(for: bleTraceCaptureConfirmationTimeout)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            completeBLETraceCaptureControl(generation: generation, didFail: true)
        }
    }

    private func receiveBLETraceSessions(_ sessions: [BLETraceSessionSummary]) {
        bleTraceSessions = sessions
        if let expectation = pendingBLETraceCaptureExpectation,
           expectation.matches(sessions) {
            completeBLETraceCaptureControl(
                generation: bleTraceCaptureControlGeneration,
                didFail: false
            )
        } else {
            render()
        }
    }

    private func completeBLETraceCaptureControl(generation: UInt64, didFail: Bool) {
        guard bleTraceCaptureControlGeneration == generation else { return }
        bleTraceCaptureControlTask?.cancel()
        bleTraceCaptureControlTask = nil
        pendingBLETraceCaptureExpectation = nil
        isBLETraceCaptureControlInProgress = false
        bleTraceError = didFail
            ? BikeDiagnosticsL10n.text(.bikeDiagnosticsBleCaptureControlError)
            : nil
        render()
    }

    private func cancelBLETraceCaptureControl() {
        guard bleTraceCaptureControlTask != nil || isBLETraceCaptureControlInProgress else { return }
        bleTraceCaptureControlGeneration &+= 1
        bleTraceCaptureControlTask?.cancel()
        bleTraceCaptureControlTask = nil
        pendingBLETraceCaptureExpectation = nil
        isBLETraceCaptureControlInProgress = false
        bleTraceError = nil
        render()
    }

}
