public struct PrepareBikeLockControlUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute() async throws -> BikeLockControlSnapshot {
        try await repository.prepareBikeLockControl()
    }
}
