import BikeDomain
import VehicleSession

public struct BikeDiagnosticsUseCases: Sendable {
    let session: any VehicleSessionService
    let connect: ConnectToBikeUseCase
    let disconnect: DisconnectBikeUseCase
    let retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase
    let observeDebugEvents: ObserveBikeDebugEventsUseCase
    let observeBLETraceSessions: ObserveBLETraceSessionsUseCase
    let prepareBLETraceExport: PrepareBLETraceExportUseCase
    let deleteBLETraceSession: DeleteBLETraceSessionUseCase
    let deleteAllBLETraceSessions: DeleteAllBLETraceSessionsUseCase

    public init(
        session: any VehicleSessionService,
        connect: ConnectToBikeUseCase,
        disconnect: DisconnectBikeUseCase,
        retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase,
        observeDebugEvents: ObserveBikeDebugEventsUseCase,
        observeBLETraceSessions: ObserveBLETraceSessionsUseCase,
        prepareBLETraceExport: PrepareBLETraceExportUseCase,
        deleteBLETraceSession: DeleteBLETraceSessionUseCase,
        deleteAllBLETraceSessions: DeleteAllBLETraceSessionsUseCase
    ) {
        self.session = session
        self.connect = connect
        self.disconnect = disconnect
        self.retrySecurityHandshake = retrySecurityHandshake
        self.observeDebugEvents = observeDebugEvents
        self.observeBLETraceSessions = observeBLETraceSessions
        self.prepareBLETraceExport = prepareBLETraceExport
        self.deleteBLETraceSession = deleteBLETraceSession
        self.deleteAllBLETraceSessions = deleteAllBLETraceSessions
    }
}
