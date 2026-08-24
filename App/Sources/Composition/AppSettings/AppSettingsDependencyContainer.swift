import AppSettings
import EnvironmentDomain
import SettingsDomain

@MainActor
struct AppSettingsDependencyContainer {
    func makeViewModel(
        settingsRepository: AppSettingsRepository,
        deviceSpeedRepository: DeviceSpeedRepository
    ) -> AppSettingsViewModel {
        AppSettingsViewModel(
            useCases: .init(
                saveSettings: SaveAppSettingsUseCase(repository: settingsRepository),
                observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
                locationAuthorizationStatus: LocationAuthorizationStatusUseCase(
                    repository: deviceSpeedRepository
                ),
                requestLocationAuthorization: RequestLocationAuthorizationUseCase(
                    repository: deviceSpeedRepository
                )
            )
        )
    }
}
