import BikeDomain

extension BikeEmulatorRepository {
    public func readBikeStatusSnapshot() async throws {
        try validateDemoConnection()
        try await refreshPowerModeConfigurations()
    }

    public func refreshPowerModeConfigurations() async throws {
        try validateDemoConnection()
        guard powerModePreset != .failure else {
            await publishDebugEvent(title: "Power modes", detail: "Simulated 4005 timeout")
            throw BikeEmulatorPowerModeError.readFailure
        }
        await publishCurrentState()
    }

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try validateDemoConnection()
        guard powerModePreset != .failure,
              currentPowerModeConfigurations()[mapIndex] != nil
        else {
            await publishDebugEvent(title: "Power modes", detail: "Simulated 4005 timeout")
            throw BikeEmulatorPowerModeError.readFailure
        }
        await publishCurrentState()
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
        try validateDemoConnection()
        guard currentPowerModeConfigurations()[mapIndex]?.hasBaseConfiguration == true else {
            throw BikeEmulatorPowerModeError.readFailure
        }
        preparedPowerModeIndexes.insert(mapIndex)
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug no-op confirmed for map \(mapIndex + 1)"
        )
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try validateDemoConnection()
        guard preparedPowerModeIndexes.contains(mapIndex),
              var configuration = currentPowerModeConfigurations()[mapIndex]
        else {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        guard BikeEmulatorConstants.powerModeHorsepowerRange.contains(horsepower),
              BikeEmulatorConstants.powerModeRegenerationRange.contains(regenerativeBrakingPercent)
        else {
            throw BikeEmulatorPowerModeError.invalidConfiguration
        }
        configuration.horsepower = horsepower
        configuration.regenerativeBrakingPercent = Double(regenerativeBrakingPercent)
        powerModeOverrides[mapIndex] = configuration
        persistState()
        await publishCurrentState()
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug map \(mapIndex + 1) write confirmed"
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        try validateDemoConnection()
        guard currentPowerModeConfigurations()[mapIndex]?.hasTractionControlConfiguration == true else {
            throw BikeEmulatorPowerModeError.readFailure
        }
        preparedTractionControlIndexes.insert(mapIndex)
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug TC no-op confirmed for map \(mapIndex + 1)"
        )
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try validateDemoConnection()
        guard preparedTractionControlIndexes.contains(mapIndex),
              var configuration = currentPowerModeConfigurations()[mapIndex]
        else {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        guard self.configuration.isDemo || (
            powerTractionPercent.rounded() == powerTractionPercent
                && brakingTractionPercent.rounded() == brakingTractionPercent
        ) else { throw BikeEmulatorPowerModeError.invalidConfiguration }
        guard BikeEmulatorConstants.tractionControlRange.contains(powerTractionPercent),
              BikeEmulatorConstants.tractionControlRange.contains(brakingTractionPercent),
              abs((powerTractionPercent * 10).rounded() - powerTractionPercent * 10) < 0.000_001,
              abs((brakingTractionPercent * 10).rounded() - brakingTractionPercent * 10) < 0.000_001
        else {
            throw BikeEmulatorPowerModeError.invalidConfiguration
        }
        configuration.powerTractionPercent = powerTractionPercent
        configuration.brakingTractionPercent = brakingTractionPercent
        powerModeOverrides[mapIndex] = configuration
        persistState()
        await publishCurrentState()
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug TC map \(mapIndex + 1) write confirmed"
        )
    }
}
