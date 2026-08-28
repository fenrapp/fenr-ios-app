import SettingsDomain
import TestSupport

actor PowerModeSettingsRepository: AppSettingsRepository {
    private let hub = TestEventHub<AppSettings>()
    private(set) var settings = AppSettings()

    func load() -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) async {
        self.settings = settings
        await hub.send(settings)
    }

    func observe() async -> AsyncStream<AppSettings> {
        await hub.stream(replay: settings)
    }
}
