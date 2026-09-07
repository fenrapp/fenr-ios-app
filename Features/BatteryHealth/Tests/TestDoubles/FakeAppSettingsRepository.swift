import SettingsDomain

actor FakeAppSettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func update(expectedVIN _: String, change _: AppSettingsChange) throws -> AppSettingsUpdateResult {
        throw AppSettingsUpdateError.invalidChange
    }
    func observe() async -> AsyncStream<AppSettingsSnapshot> {
        AsyncStream { continuation in
            continuation.yield(.init(settings: .init(), revision: 0))
        }
    }
}
