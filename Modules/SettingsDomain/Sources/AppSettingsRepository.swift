public protocol AppSettingsRepository: Sendable {
    func load() async -> AppSettings
    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult
    func observe() async -> AsyncStream<AppSettingsSnapshot>
}
