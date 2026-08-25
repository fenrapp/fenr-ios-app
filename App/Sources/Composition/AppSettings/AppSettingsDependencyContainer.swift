import AppSettings
import BikeDomain
import EnvironmentDomain
import SettingsDomain

@MainActor
struct AppSettingsDependencyContainer {
    func makeViewModel(
        settingsRepository: AppSettingsRepository,
        deviceSpeedRepository: DeviceSpeedRepository,
        bikeRepository: any BikeRepository,
        profileRepository: any BikeProfileRepository
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
                ),
                loadBikeProfile: LoadBikeProfileUseCase(repository: profileRepository),
                observeBikeProfile: ObserveBikeProfileUseCase(repository: profileRepository),
                saveBikeProfile: SaveBikeProfileUseCase(repository: profileRepository),
                observeBikeConnection: ObserveBikeConnectionUseCase(repository: bikeRepository),
                refreshBikePowerModes: RefreshBikePowerModesUseCase(repository: bikeRepository)
            ),
            mapper: AppSettingsViewStateMapper()
        )
    }
}
