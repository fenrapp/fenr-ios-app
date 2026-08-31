import BikeDomain

extension BikeEmulatorRepository {
    public func setScenario(_ scenario: BikeEmulatorScenario) async {
        self.scenario = scenario
        tick = 0
        chargePowerLimitWatts = BikeEmulatorConstants.defaultChargePowerWatts
        chargeTargetPercent = BikeEmulatorConstants.defaultChargeTargetPercent
        invalidateControlPreparations()
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Scenario: \(scenario.displayName)")
    }

    public func currentScenario() -> BikeEmulatorScenario {
        scenario
    }

    public func setPowerModePreset(_ preset: BikeEmulatorPowerModePreset) async {
        powerModePreset = preset
        powerModeOverrides.removeAll()
        preparedPowerModeIndexes.removeAll()
        preparedTractionControlIndexes.removeAll()
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Preset: \(preset.displayName)")
    }

    public func setActiveMap(_ visibleMap: Int) async {
        activeMapNumber = max(1, min(5, visibleMap))
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Active map: \(activeMapNumber)")
    }
}
