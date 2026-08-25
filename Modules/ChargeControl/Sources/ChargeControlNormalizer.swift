public struct ChargeControlNormalizer {
    public init() {}

    func powerWatts(_ watts: Int, maximumWatts: Int) -> Int {
        let clamped = min(max(watts, ChargeControlConstants.minimumPowerWatts), maximumWatts)
        return (clamped / ChargeControlConstants.powerStepWatts) * ChargeControlConstants.powerStepWatts
    }

    func targetPercent(_ percent: Int) -> Int {
        min(max(percent, ChargeControlConstants.minimumTargetPercent), ChargeControlConstants.maximumTargetPercent)
    }
}

enum ChargeControlConstants {
    static let minimumPowerWatts = 300
    static let powerStepWatts = 100
    static let minimumTargetPercent = 1
    static let maximumTargetPercent = 100
    static let targetStepPercent = 1
    static let maximumLogLines = 40
}
