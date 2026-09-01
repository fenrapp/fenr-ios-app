public struct SetChargeTargetUseCase: Sendable {
    private let repository: any BikeChargePowerControlRepository

    public init(repository: any BikeChargePowerControlRepository) {
        self.repository = repository
    }

    public func execute(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try await repository.setChargeTarget(percent: percent)
    }
}
