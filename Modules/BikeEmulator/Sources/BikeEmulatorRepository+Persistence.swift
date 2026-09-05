import BikeDomain

extension BikeEmulatorRepository {
    public func persistentState() -> BikeEmulatorState {
        var state = BikeEmulatorState(
            scenario: scenario, powerModePreset: powerModePreset, activeMap: activeMapNumber
        )
        state.chargePowerWatts = chargePowerLimitWatts
        state.chargeTargetPercent = chargeTargetPercent
        state.isBikeLocked = isBikeLocked
        state.distanceKilometers = distanceKilometers
        state.maps = powerModeOverrides.values.sorted { $0.mapIndex < $1.mapIndex }.map(BikeEmulatorState.Map.init)
        return state
    }

    func validateDemoConnection() throws {
        try Task.checkCancellation()
        if configuration.isDemo, lifecycleState != .started || !isConnected {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
    }

    func persistState() {
        configuration.persist(persistentState())
    }
}
