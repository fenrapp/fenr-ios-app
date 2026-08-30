public struct SetBikeLockedUseCase: Sendable {
    private let repository: any BikeControlRepository

    public init(repository: any BikeControlRepository) {
        self.repository = repository
    }

    public func execute(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        try await repository.setBikeLocked(isLocked)
    }
}
