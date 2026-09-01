import BikeDomain
import EnvironmentDomain
import SettingsDomain

public struct AppSettingsUseCases: Sendable {
    public struct Settings: Sendable {
        let save: SaveAppSettingsUseCase
        let observe: ObserveAppSettingsUseCase

        public init(save: SaveAppSettingsUseCase, observe: ObserveAppSettingsUseCase) {
            self.save = save
            self.observe = observe
        }
    }

    public struct Location: Sendable {
        let authorizationStatus: LocationAuthorizationStatusUseCase
        let requestAuthorization: RequestLocationAuthorizationUseCase

        public init(
            authorizationStatus: LocationAuthorizationStatusUseCase,
            requestAuthorization: RequestLocationAuthorizationUseCase
        ) {
            self.authorizationStatus = authorizationStatus
            self.requestAuthorization = requestAuthorization
        }
    }

    public struct Profile: Sendable {
        let observe: ObserveBikeProfileUseCase
        let save: SaveBikeProfileUseCase

        public init(observe: ObserveBikeProfileUseCase, save: SaveBikeProfileUseCase) {
            self.observe = observe
            self.save = save
        }
    }

    public struct PowerTierVerification: Sendable {
        let observeConnection: ObserveBikeConnectionUseCase
        let refreshPowerModes: RefreshBikePowerModesUseCase

        public init(
            observeConnection: ObserveBikeConnectionUseCase,
            refreshPowerModes: RefreshBikePowerModesUseCase
        ) {
            self.observeConnection = observeConnection
            self.refreshPowerModes = refreshPowerModes
        }
    }

    let settings: Settings
    let location: Location?
    let profile: Profile?
    let powerTierVerification: PowerTierVerification?

    public init(
        settings: Settings,
        location: Location? = nil,
        profile: Profile? = nil,
        powerTierVerification: PowerTierVerification? = nil
    ) {
        self.settings = settings
        self.location = location
        self.profile = profile
        self.powerTierVerification = powerTierVerification
    }
}
