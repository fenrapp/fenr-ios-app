import BikeDomain

struct PowerModeCurveWriteResult: Sendable {
    let configuration: BikeAdvancedPowerModeConfiguration?
    let succeeded: Bool
}
