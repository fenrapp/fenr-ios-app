import BikeDomain
import EnvironmentDomain
import RideDashboard
import SettingsDomain

@MainActor
struct RideDashboardDependencyContainer {
    func makeViewModel(
        repository: BikeRepository,
        settingsRepository: AppSettingsRepository,
        deviceSpeedRepository: DeviceSpeedRepository
    ) -> RideDashboardViewModel {
        RideDashboardViewModel(
            useCases: .init(
                observeTelemetry: ObserveBikeTelemetryUseCase(repository: repository),
                observeConnection: ObserveBikeConnectionUseCase(repository: repository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
                observeDeviceSpeed: ObserveDeviceSpeedUseCase(repository: deviceSpeedRepository),
                readBikeStatusSnapshot: ReadBikeStatusSnapshotUseCase(repository: repository)
            )
        )
    }
}
