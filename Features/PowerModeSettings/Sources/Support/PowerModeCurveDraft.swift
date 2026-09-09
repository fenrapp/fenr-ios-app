import BikeDomain

struct PowerModeCurveDraft {
    let baseline: BikeAdvancedPowerModeConfiguration
    var configuration: BikeAdvancedPowerModeConfiguration
    var powerPoints: [Double]
    var regenerationPoints: [Double]

    var hasChanges: Bool { configuration != baseline }
}
