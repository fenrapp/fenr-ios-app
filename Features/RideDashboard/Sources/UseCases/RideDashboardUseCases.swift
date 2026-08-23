import BikeDomain
import EnvironmentDomain
import SettingsDomain

public struct RideDashboardUseCases: Sendable {
    let observeTelemetry: ObserveBikeTelemetryUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    let readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase

    public init(
        observeTelemetry: ObserveBikeTelemetryUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase
    ) {
        self.observeTelemetry = observeTelemetry
        self.observeConnection = observeConnection
        self.observeSettings = observeSettings
        self.observeDeviceSpeed = observeDeviceSpeed
        self.readBikeStatusSnapshot = readBikeStatusSnapshot
    }
}
