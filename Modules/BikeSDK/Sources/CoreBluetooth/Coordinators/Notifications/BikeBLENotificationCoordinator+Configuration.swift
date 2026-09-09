import Foundation

extension BikeBLENotificationCoordinator {
    public func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        try await withConfigurationSequence {
            try await chargePowerCoordinator.prepareChargePowerControl(context: context)
        }
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        try await withConfigurationSequence {
            try await chargePowerCoordinator.setChargePowerLimit(watts: watts)
        }
    }

    public func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        try await withConfigurationSequence {
            try await chargePowerCoordinator.setChargeTarget(percent: percent)
        }
    }

    public func refreshPowerModeConfigurations() async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.refresh()
        }
    }

    public func prepareBikeLockControl() async throws -> BikeSDKBikeLockControlSnapshot {
        try await withConfigurationSequence {
            try await bikeLockCoordinator.prepare()
        }
    }

    public func setBikeLocked(_ isLocked: Bool) async throws -> BikeSDKBikeLockControlSnapshot {
        try await withConfigurationSequence {
            try await bikeLockCoordinator.setLocked(isLocked)
        }
    }

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.refreshPowerModeConfiguration(mapIndex: mapIndex)
        }
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.preparePowerModeControl(mapIndex: mapIndex)
        }
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.setPowerModeConfiguration(
                mapIndex: mapIndex,
                horsepower: horsepower,
                regenerativeBrakingPercent: regenerativeBrakingPercent
            )
        }
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.prepareTractionControl(mapIndex: mapIndex)
        }
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.setTractionControlConfiguration(
                mapIndex: mapIndex,
                powerTractionPercent: powerTractionPercent,
                brakingTractionPercent: brakingTractionPercent
            )
        }
    }

    public func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await withConfigurationSequence {
            try await powerModeCoordinator.refreshTractionControlConfiguration(mapIndex: mapIndex)
        }
    }

    public func readBikeLockFirmwareCompatibility() async throws -> BikeSDKBikeLockFirmwareCompatibility {
        try await withConfigurationSequence {
            try await bikeLockCoordinator.readFirmwareCompatibility()
        }
    }

    public func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        try await withConfigurationSequence { try await advancedPowerModeCoordinator.read(mapIndex: mapIndex) }
    }

    public func applyAdvancedPowerMode(
        expected: BikeSDKAdvancedPowerModeConfiguration,
        desired: BikeSDKAdvancedPowerModeConfiguration
    ) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        try await withConfigurationSequence {
            try await advancedPowerModeCoordinator.apply(expected: expected, desired: desired)
        }
    }

    public func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        try await withConfigurationSequence {
            try await advancedPowerModeCoordinator.applyBasic(
                mapIndex: mapIndex, horsepower: horsepower, regeneration: regeneration
            )
        }
    }

    private func withConfigurationSequence<Value: Sendable>(
        _ operation: @MainActor () async throws -> Value
    ) async throws -> Value {
        let generation = advancedPowerModeCoordinator.generation
        try await configurationSequenceGate.acquireCancellable()
        do {
            try advancedPowerModeCoordinator.check(generation)
            let value = try await operation()
            try advancedPowerModeCoordinator.check(generation)
            await configurationSequenceGate.release()
            return value
        } catch {
            await configurationSequenceGate.release()
            throw error
        }
    }
}
