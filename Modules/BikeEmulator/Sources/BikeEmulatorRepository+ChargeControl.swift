import BikeDomain

extension BikeEmulatorRepository {
    public func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        try validateDemoConnection()
        guard scenario.supportsChargeControl else {
            throw BikeEmulatorChargeControlError.chargerUnavailable
        }
        isChargePowerPrepared = true
        return makeChargeControlSnapshot(
            watts: Int(chargingStatus.maximumPowerWatts.rounded()),
            targetPercent: chargingStatus.maximumStateOfChargePercent,
            lastWriteHex: BikeEmulatorConstants.noOpWriteHex
        )
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        try validateDemoConnection()
        guard scenario.supportsChargeControl else {
            throw BikeEmulatorChargeControlError.chargerUnavailable
        }
        guard isChargePowerPrepared else {
            throw BikeEmulatorChargeControlError.controlNotPrepared
        }
        guard BikeEmulatorConstants.minimumChargePowerWatts ...
            BikeEmulatorConstants.maximumChargePowerWatts ~= watts
        else {
            throw BikeEmulatorChargeControlError.invalidPower
        }
        chargePowerLimitWatts = watts
        persistState()
        await publishCurrentState()
        return makeChargeControlSnapshot(
            watts: watts,
            targetPercent: chargeTargetPercent,
            lastWriteHex: "DEBUG POWER \(watts)"
        )
    }

    public func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try validateDemoConnection()
        guard scenario.supportsChargeControl else {
            throw BikeEmulatorChargeControlError.chargerUnavailable
        }
        guard isChargePowerPrepared else {
            throw BikeEmulatorChargeControlError.controlNotPrepared
        }
        guard BikeEmulatorConstants.minimumChargeTargetPercent ...
            BikeEmulatorConstants.maximumChargeTargetPercent ~= percent
        else {
            throw BikeEmulatorChargeControlError.invalidTarget
        }
        chargeTargetPercent = percent
        persistState()
        await publishCurrentState()
        return makeChargeControlSnapshot(
            watts: chargePowerLimitWatts,
            targetPercent: percent,
            lastWriteHex: "DEBUG TARGET \(percent)"
        )
    }

    private func makeChargeControlSnapshot(
        watts: Int,
        targetPercent: Int,
        lastWriteHex: String
    ) -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0",
            isFirmwareCompatible: true,
            readRequestHex: "DEBUG READ 4005",
            readResponseHex: "DEBUG POWER \(watts) TARGET \(targetPercent)",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: Int(
                    (Double(watts) / BikeEmulatorConstants.chargingBusVoltage * 10).rounded()
                ),
                chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: targetPercent * 10,
                standardChargerMaximumPowerWatts: BikeEmulatorConstants.maximumChargePowerWatts,
                backpackChargerMaximumPowerWatts: BikeEmulatorConstants.maximumChargePowerWatts
            ),
            lastWriteHex: lastWriteHex,
            didPassNoOpWrite: true,
            logLines: ["Debug charge control confirmed"]
        )
    }
}

enum BikeEmulatorChargeControlError: Error {
    case chargerUnavailable
    case controlNotPrepared
    case invalidPower
    case invalidTarget
}
