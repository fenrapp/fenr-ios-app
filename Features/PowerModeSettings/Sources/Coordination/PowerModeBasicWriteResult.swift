import BikeDomain

struct PowerModeBasicWriteResult: Sendable {
    enum Values: Sendable {
        case base(horsepower: Int, regeneration: Int)
        case traction(power: Double, braking: Double)
    }
    let advanced: BikeAdvancedPowerModeConfiguration?
    let values: Values?
    let error: String?
}
