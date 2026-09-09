import BikeDomain

extension BikeEmulatorRepository {
    public func setScenario(_ scenario: BikeEmulatorScenario) async {
        guard !Task.isCancelled, !configuration.isDemo || lifecycleState == .started else { return }
        if configuration.isDemo {
            guard self.scenario != scenario else { return }
            if self.scenario.supportsChargeControl != scenario.supportsChargeControl {
                isChargePowerPrepared = false
            }
        } else {
            invalidateControlPreparations()
        }
        self.scenario = scenario
        tick = 0
        if !configuration.isDemo {
            chargePowerLimitWatts = BikeEmulatorConstants.defaultChargePowerWatts
            chargeTargetPercent = BikeEmulatorConstants.defaultChargeTargetPercent
        }
        persistState()
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Scenario: \(scenario.displayName)")
    }

    public func currentScenario() -> BikeEmulatorScenario {
        scenario
    }

    public func setPowerModePreset(_ preset: BikeEmulatorPowerModePreset) async {
        powerModePreset = preset
        powerModeOverrides.removeAll()
        powerCurves.reset()
        preparedPowerModeIndexes.removeAll()
        preparedTractionControlIndexes.removeAll()
        persistState()
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Preset: \(preset.displayName)")
    }

    public func setActiveMap(_ visibleMap: Int) async {
        activeMapNumber = max(1, min(5, visibleMap))
        persistState()
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Active map: \(activeMapNumber)")
    }
}
