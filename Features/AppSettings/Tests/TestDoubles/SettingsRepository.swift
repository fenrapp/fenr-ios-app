import EnvironmentDomain
import SettingsDomain

actor SettingsRepository: AppSettingsRepository, DeviceSpeedRepository {
    var settings = AppSettings()

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { $0.finish() } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}
}
