public protocol BikeBatteryHealthRepository: Sendable {
    func startBatteryHealthMonitoring() async throws
    func stopBatteryHealthMonitoring() async
    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth>
    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture>
    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot
    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot
    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot
}

public extension BikeBatteryHealthRepository {
    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        throw BikeBatteryHealthRepositoryError.chargePowerControlUnavailable
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        throw BikeBatteryHealthRepositoryError.chargePowerControlUnavailable
    }

    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        throw BikeBatteryHealthRepositoryError.chargePowerControlUnavailable
    }
}

public enum BikeBatteryHealthRepositoryError: Error, Equatable, Sendable {
    case chargePowerControlUnavailable
}
