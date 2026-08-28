public struct RefreshBikeTractionControlConfigurationUseCase: Sendable {
    private let repository: BikeRepository

    public init(repository: BikeRepository) {
        self.repository = repository
    }

    public func execute(mapIndex: Int) async throws {
        try await repository.refreshTractionControlConfiguration(mapIndex: mapIndex)
    }
}
