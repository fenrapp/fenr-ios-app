public struct SetBikeLockedUseCase: Sendable {
    private let repository: any BikeRepository

    public init(repository: any BikeRepository) {
        self.repository = repository
    }

    public func execute(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        try await repository.setBikeLocked(isLocked)
    }
}
