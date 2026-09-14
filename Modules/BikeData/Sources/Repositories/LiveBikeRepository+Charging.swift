import BikeDomain

extension LiveBikeRepository {
    public func readChargeConfiguration() async throws -> BikeChargePowerControlSnapshot {
        try await controlService.readChargeConfiguration()
    }

    public func applyChargePower(
        watts: Int, chargerType: BikeChargerType
    ) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.applyChargePower(watts: watts, chargerType: chargerType)
    }

    public func applyChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.applyChargeTarget(percent: percent)
    }

    public func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.prepareChargePowerControl(chargingStatus: chargingStatus)
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.setChargePowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.setChargeTarget(percent: percent)
    }
}
