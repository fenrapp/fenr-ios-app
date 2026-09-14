public protocol BikeChargePowerControlRepository: Sendable {
    func readChargeConfiguration() async throws -> BikeChargePowerControlSnapshot
    func applyChargePower(watts: Int, chargerType: BikeChargerType) async throws -> BikeChargePowerControlSnapshot
    func applyChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot
    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot
    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot
    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot
}

public extension BikeChargePowerControlRepository {
    func readChargeConfiguration() async throws -> BikeChargePowerControlSnapshot {
        throw BikeChargePowerControlRepositoryError.chargePowerControlUnavailable
    }

    func applyChargePower(watts: Int, chargerType: BikeChargerType) async throws -> BikeChargePowerControlSnapshot {
        throw BikeChargePowerControlRepositoryError.chargePowerControlUnavailable
    }

    func applyChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        throw BikeChargePowerControlRepositoryError.chargePowerControlUnavailable
    }

    func prepareChargePowerControl(
        chargingStatus _: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        throw BikeChargePowerControlRepositoryError.chargePowerControlUnavailable
    }

    func setChargePowerLimit(watts _: Int) async throws -> BikeChargePowerControlSnapshot {
        throw BikeChargePowerControlRepositoryError.chargePowerControlUnavailable
    }

    func setChargeTarget(percent _: Int) async throws -> BikeChargePowerControlSnapshot {
        throw BikeChargePowerControlRepositoryError.chargePowerControlUnavailable
    }
}

public enum BikeChargePowerControlRepositoryError: Error, Equatable, Sendable {
    case chargePowerControlUnavailable
}
