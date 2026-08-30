public struct SetChargePowerLimitUseCase: Sendable {
    private let repository: any BikeChargePowerControlRepository

    public init(repository: any BikeChargePowerControlRepository) {
        self.repository = repository
    }

    public func execute(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        try await repository.setChargePowerLimit(watts: watts)
    }
}
