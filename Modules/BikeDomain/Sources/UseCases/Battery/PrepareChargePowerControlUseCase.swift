public struct PrepareChargePowerControlUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        try await repository.prepareChargePowerControl(chargingStatus: chargingStatus)
    }
}
