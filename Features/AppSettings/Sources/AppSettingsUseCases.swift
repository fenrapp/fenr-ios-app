import EnvironmentDomain
import SettingsDomain

public struct AppSettingsUseCases: Sendable {
    let loadSettings: LoadAppSettingsUseCase
    let saveSettings: SaveAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let locationAuthorizationStatus: LocationAuthorizationStatusUseCase
    let requestLocationAuthorization: RequestLocationAuthorizationUseCase

    public init(
        loadSettings: LoadAppSettingsUseCase,
        saveSettings: SaveAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        locationAuthorizationStatus: LocationAuthorizationStatusUseCase,
        requestLocationAuthorization: RequestLocationAuthorizationUseCase
    ) {
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.observeSettings = observeSettings
        self.locationAuthorizationStatus = locationAuthorizationStatus
        self.requestLocationAuthorization = requestLocationAuthorization
    }
}
