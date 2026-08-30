public struct PrepareChargePowerControlUseCase: Sendable {
    private let repository: any BikeChargePowerControlRepository

    public init(repository: any BikeChargePowerControlRepository) {
        self.repository = repository
    }

    public func execute(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        try await repository.prepareChargePowerControl(chargingStatus: chargingStatus)
    }
}
