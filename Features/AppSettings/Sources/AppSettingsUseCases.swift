import EnvironmentDomain
import SettingsDomain

public struct AppSettingsUseCases: Sendable {
    let saveSettings: SaveAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let locationAuthorizationStatus: LocationAuthorizationStatusUseCase?
    let requestLocationAuthorization: RequestLocationAuthorizationUseCase?

    public init(
        saveSettings: SaveAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        locationAuthorizationStatus: LocationAuthorizationStatusUseCase? = nil,
        requestLocationAuthorization: RequestLocationAuthorizationUseCase? = nil
    ) {
        self.saveSettings = saveSettings
        self.observeSettings = observeSettings
        self.locationAuthorizationStatus = locationAuthorizationStatus
        self.requestLocationAuthorization = requestLocationAuthorization
    }
}
