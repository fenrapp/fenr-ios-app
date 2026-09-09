import BikeDomain

struct PowerModePresetCompatibility: Sendable {
    func accepts(
        _ preset: BikePowerModePreset, configuration: BikeAdvancedPowerModeConfiguration?, maximum: Int
    ) -> Bool {
        guard let configuration else { return false }
        let value = preset.configuration
        return preset.maximumHorsepower == maximum
            && preset.calibrationProfileID == BikePowerCurveCalibration.profileID
            && value.firmware == configuration.firmware
            && value.power.count == BikePowerCurveCalibration.sampleCount
            && value.regeneration.count == BikePowerCurveCalibration.sampleCount
            && value.power.allSatisfy { 0 ... 1_000 ~= $0 }
            && value.regeneration.allSatisfy { 0 ... 1_000 ~= $0 }
            && (value.powerTractionRaw == nil) == (configuration.powerTractionRaw == nil)
            && (value.brakingTractionRaw == nil) == (configuration.brakingTractionRaw == nil)
    }
}
