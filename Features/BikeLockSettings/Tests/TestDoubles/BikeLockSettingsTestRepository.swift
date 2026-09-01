import SettingsDomain

actor BikeLockSettingsTestRepository: AppSettingsRepository {
    private var settings: AppSettings
    private var savedSettings: [AppSettings] = []

    init(settings: AppSettings) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }

    func save(_ settings: AppSettings) {
        self.settings = settings
        savedSettings.append(settings)
    }

    func observe() -> AsyncStream<AppSettings> { .init { $0.finish() } }
    func saveCount() -> Int { savedSettings.count }
}
