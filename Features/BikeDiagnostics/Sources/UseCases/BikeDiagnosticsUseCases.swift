import BikeDomain
import VehicleSession

public struct BikeDiagnosticsUseCases: Sendable {
    let session: any VehicleSessionService
    let connect: ConnectToBikeUseCase
    let disconnect: DisconnectBikeUseCase
    let retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase
    let startNewDiagnosticsCapture: StartNewBikeDiagnosticsCaptureUseCase
    let stopDiagnosticsCapture: StopBikeDiagnosticsCaptureUseCase
    let observeDebugEvents: ObserveBikeDebugEventsUseCase
    let observeBLETraceSessions: ObserveBLETraceSessionsUseCase
    let observeBLETraceRecordingFailures: ObserveBLETraceRecordingFailuresUseCase
    let prepareBLETraceExport: PrepareBLETraceExportUseCase
    let deleteBLETraceSession: DeleteBLETraceSessionUseCase
    let deleteAllBLETraceSessions: DeleteAllBLETraceSessionsUseCase

    public init(
        session: any VehicleSessionService,
        connect: ConnectToBikeUseCase,
        disconnect: DisconnectBikeUseCase,
        retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase,
        startNewDiagnosticsCapture: StartNewBikeDiagnosticsCaptureUseCase,
        stopDiagnosticsCapture: StopBikeDiagnosticsCaptureUseCase,
        observeDebugEvents: ObserveBikeDebugEventsUseCase,
        observeBLETraceSessions: ObserveBLETraceSessionsUseCase,
        observeBLETraceRecordingFailures: ObserveBLETraceRecordingFailuresUseCase,
        prepareBLETraceExport: PrepareBLETraceExportUseCase,
        deleteBLETraceSession: DeleteBLETraceSessionUseCase,
        deleteAllBLETraceSessions: DeleteAllBLETraceSessionsUseCase
    ) {
        self.session = session
        self.connect = connect
        self.disconnect = disconnect
        self.retrySecurityHandshake = retrySecurityHandshake
        self.startNewDiagnosticsCapture = startNewDiagnosticsCapture
        self.stopDiagnosticsCapture = stopDiagnosticsCapture
        self.observeDebugEvents = observeDebugEvents
        self.observeBLETraceSessions = observeBLETraceSessions
        self.observeBLETraceRecordingFailures = observeBLETraceRecordingFailures
        self.prepareBLETraceExport = prepareBLETraceExport
        self.deleteBLETraceSession = deleteBLETraceSession
        self.deleteAllBLETraceSessions = deleteAllBLETraceSessions
    }
}
