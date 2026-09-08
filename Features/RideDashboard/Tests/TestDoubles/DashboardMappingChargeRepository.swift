import BikeDomain

actor DashboardMappingChargeRepository: BikeChargePowerControlRepository {
    private var watts = 1_000
    private var target = 100
    private(set) var powerWrites: [Int] = []
    private(set) var targetWrites: [Int] = []

    func prepareChargePowerControl(chargingStatus: BikeChargingStatus) -> BikeChargePowerControlSnapshot {
        watts = Int(chargingStatus.maximumPowerWatts)
        target = chargingStatus.maximumStateOfChargePercent
        return snapshot()
    }

    func setChargePowerLimit(watts: Int) -> BikeChargePowerControlSnapshot {
        powerWrites.append(watts)
        self.watts = watts
        return snapshot()
    }

    func setChargeTarget(percent: Int) -> BikeChargePowerControlSnapshot {
        targetWrites.append(percent)
        target = percent
        return snapshot()
    }

    private func snapshot() -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0", isFirmwareCompatible: true,
            readRequestHex: "00 04", readResponseHex: "01 04",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 20, chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: target * 10,
                standardChargerMaximumPowerWatts: 3_300, backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "01 04 01", didPassNoOpWrite: true, logLines: []
        )
    }
}
