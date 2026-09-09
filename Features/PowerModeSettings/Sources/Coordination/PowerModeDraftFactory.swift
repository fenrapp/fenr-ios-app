import BikeDomain

struct PowerModeDraftFactory: Sendable {
    let calibration: BikePowerCurveCalibration

    func makeDraft(_ configuration: BikeAdvancedPowerModeConfiguration, maximum: Int) -> PowerModeCurveDraft {
        .init(
            baseline: configuration, configuration: configuration,
            powerPoints: calibration.editorPower(configuration.power, maximumHorsepower: maximum),
            regenerationPoints: BikePowerCurveCalibration.editorSampleIndexes.map {
                Double(configuration.regeneration[$0]) / 10
            }
        )
    }

}
