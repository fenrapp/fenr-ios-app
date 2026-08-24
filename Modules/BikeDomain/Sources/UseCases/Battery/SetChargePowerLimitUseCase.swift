public struct SetChargePowerLimitUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        try await repository.setChargePowerLimit(watts: watts)
    }
}
