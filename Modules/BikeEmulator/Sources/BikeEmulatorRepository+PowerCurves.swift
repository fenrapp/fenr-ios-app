import BikeDomain

extension BikeEmulatorRepository {
    nonisolated public var supportsAdvancedPowerModes: Bool { true }

    public func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeAdvancedPowerModeConfiguration {
        try validateDemoConnection()
        guard isConnected, powerModePreset != .failure,
              let basic = currentPowerModeConfigurations()[mapIndex] else {
            throw BikeEmulatorPowerModeError.readFailure
        }
        return try powerCurves.read(basic, maximum: maximumCurveHorsepower)
    }

    public func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        let current = try await readAdvancedPowerMode(mapIndex: mapIndex)
        let desired = try powerCurves.changingBasic(
            current, horsepower: horsepower, regeneration: regeneration, maximum: maximumCurveHorsepower
        )
        return try await applyPowerCurves(expected: current, desired: desired, isAdvancedEdit: false)
    }

    public func applyAdvancedPowerMode(
        expected: BikeAdvancedPowerModeConfiguration, desired: BikeAdvancedPowerModeConfiguration
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        try await applyPowerCurves(expected: expected, desired: desired, isAdvancedEdit: true)
    }

    private func applyPowerCurves(
        expected: BikeAdvancedPowerModeConfiguration, desired: BikeAdvancedPowerModeConfiguration,
        isAdvancedEdit: Bool
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        _ = try await readAdvancedPowerMode(mapIndex: expected.mapIndex)
        try validateDemoConnection()
        powerModeOverrides[desired.mapIndex] = try powerCurves.apply(
            expected: expected, desired: desired, maximum: maximumCurveHorsepower, isAdvancedEdit: isAdvancedEdit
        )
        persistState()
        await publishCurrentState()
        return desired
    }

    private var maximumCurveHorsepower: Int {
        powerModePreset.declaredTier == .alpha || powerModePreset == .mismatch ? 80 : 60
    }
}
