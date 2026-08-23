public struct LoadAppSettingsUseCase: Sendable {
    private let repository: AppSettingsRepository

    public init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> AppSettings {
        await repository.load()
    }
}

public struct SaveAppSettingsUseCase: Sendable {
    private let repository: AppSettingsRepository

    public init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    public func execute(_ settings: AppSettings) async {
        await repository.save(settings)
    }
}

public struct ObserveAppSettingsUseCase: Sendable {
    private let repository: AppSettingsRepository

    public init(repository: AppSettingsRepository) {
        self.repository = repository
    }

    public func execute() async -> AsyncStream<AppSettings> {
        await repository.observe()
    }
}
