import BikeDomain
import SettingsDomain

public struct BikeDiagnosticsUseCases: Sendable {
    let start: StartBikeRepositoryUseCase
    let stop: StopBikeRepositoryUseCase
    let connect: ConnectToBikeUseCase
    let disconnect: DisconnectBikeUseCase
    let retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase
    let readTelemetrySnapshot: ReadBikeTelemetrySnapshotUseCase
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeDebugEvents: ObserveBikeDebugEventsUseCase
    let derivePin: DeriveBikePinUseCase
    let loadProfile: LoadBikeProfileUseCase
    let observeSettings: ObserveAppSettingsUseCase

    public init(
        start: StartBikeRepositoryUseCase,
        stop: StopBikeRepositoryUseCase,
        connect: ConnectToBikeUseCase,
        disconnect: DisconnectBikeUseCase,
        retrySecurityHandshake: RetryBikeSecurityHandshakeUseCase,
        readTelemetrySnapshot: ReadBikeTelemetrySnapshotUseCase,
        observeTelemetry: ObserveBikeTelemetryUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeDebugEvents: ObserveBikeDebugEventsUseCase,
        derivePin: DeriveBikePinUseCase,
        loadProfile: LoadBikeProfileUseCase,
        observeSettings: ObserveAppSettingsUseCase
    ) {
        self.start = start
        self.stop = stop
        self.connect = connect
        self.disconnect = disconnect
        self.retrySecurityHandshake = retrySecurityHandshake
        self.readTelemetrySnapshot = readTelemetrySnapshot
        self.observeTelemetry = observeTelemetry
        self.observeConnection = observeConnection
        self.observeDebugEvents = observeDebugEvents
        self.derivePin = derivePin
        self.loadProfile = loadProfile
        self.observeSettings = observeSettings
    }
}
