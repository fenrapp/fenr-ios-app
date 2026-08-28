public struct PrepareBikeTractionControlUseCase: Sendable {
    private let repository: any BikeRepository

    public init(repository: any BikeRepository) {
        self.repository = repository
    }

    public func execute(mapIndex: Int) async throws {
        try await repository.prepareTractionControl(mapIndex: mapIndex)
    }
}
