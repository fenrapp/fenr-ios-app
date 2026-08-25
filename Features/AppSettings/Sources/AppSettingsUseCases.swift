import BikeDomain
import EnvironmentDomain
import SettingsDomain

public struct AppSettingsUseCases: Sendable {
    let saveSettings: SaveAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let locationAuthorizationStatus: LocationAuthorizationStatusUseCase?
    let requestLocationAuthorization: RequestLocationAuthorizationUseCase?
    let loadBikeProfile: LoadBikeProfileUseCase?
    let observeBikeProfile: ObserveBikeProfileUseCase?
    let saveBikeProfile: SaveBikeProfileUseCase?
    let observeBikeConnection: ObserveBikeConnectionUseCase?
    let refreshBikePowerModes: RefreshBikePowerModesUseCase?

    public init(
        saveSettings: SaveAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        locationAuthorizationStatus: LocationAuthorizationStatusUseCase? = nil,
        requestLocationAuthorization: RequestLocationAuthorizationUseCase? = nil,
        loadBikeProfile: LoadBikeProfileUseCase? = nil,
        observeBikeProfile: ObserveBikeProfileUseCase? = nil,
        saveBikeProfile: SaveBikeProfileUseCase? = nil,
        observeBikeConnection: ObserveBikeConnectionUseCase? = nil,
        refreshBikePowerModes: RefreshBikePowerModesUseCase? = nil
    ) {
        self.saveSettings = saveSettings
        self.observeSettings = observeSettings
        self.locationAuthorizationStatus = locationAuthorizationStatus
        self.requestLocationAuthorization = requestLocationAuthorization
        self.loadBikeProfile = loadBikeProfile
        self.observeBikeProfile = observeBikeProfile
        self.saveBikeProfile = saveBikeProfile
        self.observeBikeConnection = observeBikeConnection
        self.refreshBikePowerModes = refreshBikePowerModes
    }
}
