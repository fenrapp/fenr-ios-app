public struct BatteryHealthChargeControlNormalizer {
    public init() {}

    func powerWatts(_ watts: Int, maximumWatts: Int) -> Int {
        let clamped = min(max(watts, BatteryHealthChargeControlConstants.defaultMinimumPowerWatts), maximumWatts)
        return (clamped / BatteryHealthChargeControlConstants.powerStepWatts)
            * BatteryHealthChargeControlConstants.powerStepWatts
    }

    func targetPercent(_ percent: Int) -> Int {
        let clamped = min(
            max(percent, BatteryHealthChargeControlConstants.minimumTargetPercent),
            BatteryHealthChargeControlConstants.maximumTargetPercent
        )
        return (clamped / BatteryHealthChargeControlConstants.targetStepPercent)
            * BatteryHealthChargeControlConstants.targetStepPercent
    }
}
