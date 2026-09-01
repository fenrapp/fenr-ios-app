import BikeDomain

extension BikeEmulatorRepository {
    public func readBikeStatusSnapshot() async throws {
        try await refreshPowerModeConfigurations()
    }

    public func refreshPowerModeConfigurations() async throws {
        guard powerModePreset != .failure else {
            await publishDebugEvent(title: "Power modes", detail: "Simulated 4005 timeout")
            throw BikeEmulatorPowerModeError.readFailure
        }
        await publishCurrentState()
    }

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        guard powerModePreset != .failure,
              currentPowerModeConfigurations()[mapIndex] != nil
        else {
            await publishDebugEvent(title: "Power modes", detail: "Simulated 4005 timeout")
            throw BikeEmulatorPowerModeError.readFailure
        }
        await publishCurrentState()
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
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
        await publishCurrentState()
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug map \(mapIndex + 1) write confirmed"
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
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
        guard preparedTractionControlIndexes.contains(mapIndex),
              var configuration = currentPowerModeConfigurations()[mapIndex]
        else {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        guard BikeEmulatorConstants.tractionControlRange.contains(powerTractionPercent),
              BikeEmulatorConstants.tractionControlRange.contains(brakingTractionPercent),
              powerTractionPercent.rounded() == powerTractionPercent,
              brakingTractionPercent.rounded() == brakingTractionPercent
        else {
            throw BikeEmulatorPowerModeError.invalidConfiguration
        }
        configuration.powerTractionPercent = powerTractionPercent
        configuration.brakingTractionPercent = brakingTractionPercent
        powerModeOverrides[mapIndex] = configuration
        await publishCurrentState()
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug TC map \(mapIndex + 1) write confirmed"
        )
    }
}
