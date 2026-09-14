import BikeDomain

public struct ChargingPreferencesUseCases: Sendable {
    private let repository: any BikeChargePowerControlRepository

    public init(repository: any BikeChargePowerControlRepository) { self.repository = repository }

    func read() async throws -> BikeChargePowerControlSnapshot {
        try await repository.readChargeConfiguration()
    }

    func applyPower(_ power: BikeChargingPreferences.PendingPower) async throws -> BikeChargePowerControlSnapshot {
        try await repository.applyChargePower(watts: power.watts, chargerType: power.charger)
    }

    func applyTarget(_ target: BikeChargingPreferences.PendingTarget) async throws -> BikeChargePowerControlSnapshot {
        try await repository.applyChargeTarget(percent: target.percent)
    }
}
