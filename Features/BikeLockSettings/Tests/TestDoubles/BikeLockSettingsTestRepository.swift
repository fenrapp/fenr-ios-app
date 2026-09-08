import SettingsDomain

actor BikeLockSettingsTestRepository: AppSettingsRepository {
    private var settings: AppSettings
    private var revision: UInt64 = 0
    private var savedSettings: [AppSettings] = []

    init(settings: AppSettings) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
    }

    func load() -> AppSettings { settings }

    func update(expectedVIN: String, change: AppSettingsChange) throws -> AppSettingsUpdateResult {
        guard settings.vin == expectedVIN else { throw AppSettingsUpdateError.vehicleChanged }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(.init(settings: settings, revision: revision)) }
        settings = updated
        revision += 1
        savedSettings.append(settings)
        return .changed(.init(settings: settings, revision: revision))
    }

    func observe() -> AsyncStream<AppSettingsSnapshot> { .init { $0.finish() } }
    func saveCount() -> Int { savedSettings.count }
}
