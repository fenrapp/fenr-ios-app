public struct PrepareBikeTractionControlUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute(mapIndex: Int) async throws {
        try await repository.prepareTractionControl(mapIndex: mapIndex)
    }
}
