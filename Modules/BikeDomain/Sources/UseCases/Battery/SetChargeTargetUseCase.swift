public struct SetChargeTargetUseCase: Sendable {
    private let repository: any BikeBatteryHealthRepository

    public init(repository: any BikeBatteryHealthRepository) {
        self.repository = repository
    }

    public func execute(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try await repository.setChargeTarget(percent: percent)
    }
}
