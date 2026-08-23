public protocol AppSettingsRepository: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async
    func observe() async -> AsyncStream<AppSettings>
}
