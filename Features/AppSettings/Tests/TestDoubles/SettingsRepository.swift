import EnvironmentDomain
import SettingsDomain
import TestSupport

actor SettingsRepository: AppSettingsRepository, DeviceSpeedRepository {
    private let settingsHub = TestEventHub<AppSettings>(bufferingPolicy: .bufferingNewest(1))
    private(set) var settings = AppSettings()

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) async {
        self.settings = settings
        await settingsHub.send(settings)
    }
    func observe() async -> AsyncStream<AppSettings> {
        await settingsHub.stream(replay: settings)
    }
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { $0.finish() } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}

    func waitForSettingsSubscriber() async -> Bool {
        await settingsHub.waitForSubscriber()
    }
}
