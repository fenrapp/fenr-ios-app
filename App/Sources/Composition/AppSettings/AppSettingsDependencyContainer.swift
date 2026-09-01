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
                settings: .init(
                    save: SaveAppSettingsUseCase(repository: settingsRepository),
                    observe: ObserveAppSettingsUseCase(repository: settingsRepository)
                ),
                location: .init(
                    authorizationStatus: LocationAuthorizationStatusUseCase(
                        repository: deviceSpeedRepository
                    ),
                    requestAuthorization: RequestLocationAuthorizationUseCase(
                        repository: deviceSpeedRepository
                    )
                ),
                profile: .init(
                    observe: ObserveBikeProfileUseCase(repository: profileRepository),
                    save: SaveBikeProfileUseCase(repository: profileRepository)
                ),
                powerTierVerification: .init(
                    observeConnection: ObserveBikeConnectionUseCase(repository: bikeRepository),
                    refreshPowerModes: RefreshBikePowerModesUseCase(repository: bikeRepository)
                )
            ),
            mapper: AppSettingsViewStateMapper()
        )
    }
}
