public struct PrepareBikeLockControlUseCase: Sendable {
    private let repository: any BikeRepository

    public init(repository: any BikeRepository) {
        self.repository = repository
    }

    public func execute() async throws -> BikeLockControlSnapshot {
        try await repository.prepareBikeLockControl()
    }
}
