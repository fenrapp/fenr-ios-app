import AppSettings
import BikeDomain
import EnvironmentDomain
import SettingsDomain

@MainActor
struct AppSettingsViewModelFixture {
    static let vin = "FENRTEST000000001"

    let settingsRepository: SettingsRepository
    let profileRepository: ControllableBikeProfileRepository
    let bikeRepository: ControllableBikeControlRepository
    let viewModel: AppSettingsViewModel

    init(
        profile: BikeProfile = .init(vin: Self.vin),
        refreshBehavior: ControllableBikeControlRepository.RefreshBehavior = .success
    ) {
        let settingsRepository = SettingsRepository()
        let profileRepository = ControllableBikeProfileRepository(profile: profile)
        let bikeRepository = ControllableBikeControlRepository(refreshBehavior: refreshBehavior)
        self.settingsRepository = settingsRepository
        self.profileRepository = profileRepository
        self.bikeRepository = bikeRepository
        viewModel = AppSettingsViewModel(
            useCases: .init(
                settings: .init(
                    save: .init(repository: settingsRepository),
                    observe: .init(repository: settingsRepository)
                ),
                location: .init(
                    authorizationStatus: .init(repository: settingsRepository),
                    requestAuthorization: .init(repository: settingsRepository)
                ),
                profile: .init(
                    observe: .init(repository: profileRepository),
                    save: .init(repository: profileRepository)
                ),
                powerTierVerification: .init(
                    observeConnection: .init(repository: bikeRepository),
                    refreshPowerModes: .init(repository: bikeRepository)
                )
            ),
            mapper: AppSettingsViewStateMapper()
        )
    }

    func start() async {
        viewModel.start()
        _ = await settingsRepository.waitForSettingsSubscriber()
        _ = await profileRepository.waitForProfileSubscriber()
    }
}
