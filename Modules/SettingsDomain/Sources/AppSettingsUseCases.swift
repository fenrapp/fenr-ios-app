public struct LoadAppSettingsUseCase: Sendable {
    private let repository: AppSettingsRepository

    public init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> AppSettings {
        await repository.load()
    }
}

public struct UpdateAppSettingsUseCase: Sendable {
    private let repository: AppSettingsRepository

    public init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    public func execute(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        try await repository.update(expectedVIN: expectedVIN, change: change)
    }
}

public struct ObserveAppSettingsUseCase: Sendable {
    private let repository: AppSettingsRepository

    public init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<AppSettingsSnapshot> {
        await repository.observe()
    }
}
